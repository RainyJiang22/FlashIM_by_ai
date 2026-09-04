import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_search/flash_im_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('debounces, previews three results and expands a section', (
    tester,
  ) async {
    final repository = _PageRepository();
    FriendUser? selectedFriend;
    await tester.pumpWidget(
      RepositoryProvider<SearchRepository>.value(
        value: repository,
        child: MaterialApp(
          home: SearchPage(
            onFriendTap: (friend) => selectedFriend = friend,
            onConversationTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('comprehensive-search-field')),
      '发布',
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.friendCalls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repository.friendCalls, 1);
    expect(find.byKey(const ValueKey('friend-search-result-4')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('toggle-search-friends')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('friend-search-result-4')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('friend-search-result-4')));
    expect(selectedFriend?.accountId, 4);
  });

  testWidgets(
    'multi-message group opens detail and conversation search opens item',
    (tester) async {
      final repository = _PageRepository();
      await tester.pumpWidget(
        RepositoryProvider<SearchRepository>.value(
          value: repository,
          child: MaterialApp(
            home: SearchPage(onFriendTap: (_) {}, onConversationTap: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('comprehensive-search-field')),
        '发布',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final messageGroup = find.byKey(
        const ValueKey('message-group-result-group-1'),
      );
      await tester.ensureVisible(messageGroup.first);
      await tester.pumpAndSettle();
      await tester.tap(messageGroup.first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('message-search-result-message-1')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        RepositoryProvider<SearchRepository>.value(
          value: repository,
          child: MaterialApp(
            key: UniqueKey(),
            home: ConversationSearchPage(conversation: repository.conversation),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('conversation-search-field')),
        '发布',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('message-search-result-message-1')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('single-message-content')), findsOneWidget);
    },
  );

  testWidgets('empty query displays and clears local history', (tester) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSearchHistoryStore.key: ['项目'],
    });
    await tester.pumpWidget(
      RepositoryProvider<SearchRepository>.value(
        value: _PageRepository(),
        child: MaterialApp(
          home: SearchPage(onFriendTap: (_) {}, onConversationTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-history-项目')), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear-search-history')));
    await tester.pumpAndSettle();
    expect(find.text('暂无搜索历史'), findsOneWidget);
  });
}

class _PageRepository implements SearchRepository {
  int friendCalls = 0;

  final conversation = Conversation(
    id: 'group-1',
    type: 1,
    name: '项目群',
    unreadCount: 0,
    memberCount: 4,
    createdAt: DateTime(2026),
  );

  Message get message => Message(
    id: 'message-1',
    conversationId: conversation.id,
    senderId: '2',
    senderName: '阿青',
    senderAvatar: 'identicon:2',
    seq: 2,
    content: '今天发布版本',
    status: MessageStatus.sent,
    createdAt: DateTime(2026),
  );

  @override
  Future<List<FriendUser>> searchFriends(String query) async {
    friendCalls += 1;
    return [
      for (var id = 1; id <= 4; id++)
        FriendUser(
          accountId: id,
          nickname: '好友$id',
          avatar: 'identicon:$id',
          signature: '',
          relationStatus: 'friend',
        ),
    ];
  }

  @override
  Future<List<Conversation>> searchJoinedGroups(String query) async => [
    conversation,
  ];

  @override
  Future<List<MessageSearchGroup>> searchMessages(String query) async => [
    MessageSearchGroup(
      conversation: conversation,
      matchCount: 2,
      messages: [message],
    ),
  ];

  @override
  Future<List<Message>> searchConversationMessages({
    required String conversationId,
    required String query,
  }) async => [message];
}
