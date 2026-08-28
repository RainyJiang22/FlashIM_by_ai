import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('filters existing members and returns selected friends', (
    tester,
  ) async {
    List<FriendUser>? result;
    await tester.pumpWidget(
      RepositoryProvider<FriendRepository>.value(
        value: FakeFriendRepository(friends: friends),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<List<FriendUser>>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const GroupMemberPickerPage(existingMemberIds: {2}),
                    ),
                  );
                },
                child: const Text('选择成员'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择成员'));
    await tester.pumpAndSettle();
    expect(find.text('阿青'), findsNothing);
    expect(find.text('白露'), findsOneWidget);

    await tester.tap(find.text('白露'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selected-friend-avatar-3')));
    await tester.pump();
    expect(find.text('完成(1)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected-friend-remove-3')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('group-member-picker-submit')));
    await tester.pumpAndSettle();
    expect(result?.single.accountId, 3);
  });
}
