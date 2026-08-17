import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('selects two friends and returns created conversation', (
    tester,
  ) async {
    final created = groupConversation('g1', '阿青、白露');
    Conversation? result;
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FriendRepository>.value(
            value: FakeFriendRepository(friends: friends),
          ),
          RepositoryProvider<ConversationRepository>.value(
            value: FakeConversationRepository(created: created),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Conversation>(
                    MaterialPageRoute(builder: (_) => const CreateGroupPage()),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-friend-2')));
    await tester.tap(find.byKey(const ValueKey('select-friend-3')));
    await tester.pump();
    expect(find.text('完成(2)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('selected-friend-avatar-3')));
    await tester.pump();
    expect(find.text('完成(1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('select-friend-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create-group-submit')));
    await tester.pumpAndSettle();

    expect(result, created);
  });

  testWidgets('private-chat member is selected and locked', (tester) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FriendRepository>.value(
            value: FakeFriendRepository(friends: friends),
          ),
          RepositoryProvider<ConversationRepository>.value(
            value: FakeConversationRepository(),
          ),
        ],
        child: MaterialApp(
          home: CreateGroupPage(initialMembers: [friends.first]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('完成(1)'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });

  testWidgets('shows friend load error and retries', (tester) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FriendRepository>.value(
            value: FakeFriendRepository(error: StateError('bad')),
          ),
          RepositoryProvider<ConversationRepository>.value(
            value: FakeConversationRepository(),
          ),
        ],
        child: const MaterialApp(home: CreateGroupPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('好友列表加载失败'), findsWidgets);
    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('好友列表加载失败'), findsWidgets);
  });

  testWidgets('private chat details invokes invite callback', (tester) async {
    FriendUser? invited;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivateChatDetailsPage(
          friend: friends.first,
          onInviteMore: (friend) async => invited = friend,
        ),
      ),
    );

    expect(find.text('阿青'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-more-to-group')));
    await tester.pump();
    expect(invited, friends.first);
  });
}
