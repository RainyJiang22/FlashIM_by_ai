import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('owner sees member actions, edits name and dissolves group', (
    tester,
  ) async {
    final groupRepository = FakeGroupRepository();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<GroupRepository>.value(value: groupRepository),
          RepositoryProvider<FriendRepository>.value(
            value: FakeFriendRepository(friends: friends),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<GroupDetailsResult>(
                    builder: (_) => GroupDetailsPage(
                      conversation: groupConversation('group-1', '测试群聊'),
                    ),
                  ),
                ),
                child: const Text('打开群详情'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开群详情'));
    await tester.pumpAndSettle();

    expect(find.text('2 位群成员'), findsOneWidget);
    expect(find.text('添加'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('群号'), findsOneWidget);
    expect(find.text('group-1'), findsOneWidget);
    expect(find.text('入群验证'), findsOneWidget);
    expect(find.byKey(const Key('group-dissolve-button')), findsOneWidget);
    final approvalSwitch = tester.widget<CupertinoSwitch>(
      find.byKey(const Key('group-join-approval-switch')),
    );
    expect(approvalSwitch.value, isFalse);
    expect(approvalSwitch.inactiveTrackColor, const Color(0xFFD5DCE7));
    expect(
      approvalSwitch.trackOutlineColor?.resolve(const <WidgetState>{}),
      const Color(0xFFAAB5C5),
    );

    await tester.tap(find.byKey(const Key('group-join-approval-switch')));
    await tester.pumpAndSettle();
    expect(groupRepository.detail.joinApprovalRequired, isTrue);

    await tester.tap(find.byKey(const Key('group-name-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-name-input')), '新群名');
    await tester.tap(find.byKey(const Key('group-name-save')));
    await tester.pumpAndSettle();
    expect(groupRepository.detail.name, '新群名');

    await tester.tap(find.byKey(const Key('group-dissolve-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-dissolve-confirm')));
    await tester.pumpAndSettle();
    expect(groupRepository.dissolveCount, 1);
    expect(find.text('打开群详情'), findsOneWidget);
  });

  testWidgets('member sees approval state without owner danger actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<GroupRepository>.value(
            value: FakeGroupRepository(
              detail: groupDetail(isOwner: false, joinApprovalRequired: true),
            ),
          ),
          RepositoryProvider<FriendRepository>.value(
            value: FakeFriendRepository(friends: friends),
          ),
        ],
        child: MaterialApp(
          home: GroupDetailsPage(
            conversation: groupConversation('group-1', '测试群聊'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加'), findsOneWidget);
    expect(find.text('删除'), findsNothing);
    expect(find.byKey(const Key('group-dissolve-button')), findsNothing);
    final approvalSwitch = tester.widget<CupertinoSwitch>(
      find.byKey(const Key('group-join-approval-switch')),
    );
    expect(approvalSwitch.onChanged, isNull);
  });
}
