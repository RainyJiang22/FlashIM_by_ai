import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('marks an online private peer in the conversation list', (
    tester,
  ) async {
    final repository = _ConversationRepository([
      Conversation(
        id: 'private-1',
        type: 0,
        peerUserId: '3',
        peerNickname: '阿青',
        unreadCount: 0,
        createdAt: DateTime(2026, 9, 3),
      ),
      Conversation(
        id: 'group-1',
        type: 1,
        name: '研发群',
        unreadCount: 0,
        createdAt: DateTime(2026, 9, 3),
      ),
    ]);
    final cubit = ConversationListCubit(repository: repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationListPage(cubit: cubit, onlineUserIds: const {3}),
        ),
      ),
    );
    await cubit.loadConversations();
    await tester.pumpAndSettle();

    expect(find.text('阿青'), findsOneWidget);
    expect(
      find.byKey(const Key('conversation-online-indicator')),
      findsOneWidget,
    );
  });

  testWidgets(
    'long press confirms hiding a conversation without deleting history',
    (tester) async {
      final conversation = Conversation(
        id: 'private-1',
        type: 0,
        peerUserId: '3',
        peerNickname: '阿青',
        unreadCount: 2,
        createdAt: DateTime(2026, 9, 3),
      );
      final repository = _ConversationRepository([conversation]);
      final cubit = ConversationListCubit(repository: repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ConversationListPage(cubit: cubit)),
        ),
      );
      await cubit.loadConversations();
      await tester.pumpAndSettle();

      await tester.longPress(find.text('阿青'));
      await tester.pumpAndSettle();
      expect(find.text('聊天记录会保留。该会话有新消息时，会重新出现在首页消息列表。'), findsOneWidget);

      await tester.tap(find.byKey(const Key('conversation-hide-confirm')));
      await tester.pumpAndSettle();

      expect(repository.hiddenIds, ['private-1']);
      expect(find.text('阿青'), findsNothing);
      expect(find.text('暂无会话'), findsOneWidget);
    },
  );
}

class _ConversationRepository implements ConversationRepository {
  _ConversationRepository(this.conversations);

  final List<Conversation> conversations;
  final List<String> hiddenIds = <String>[];

  @override
  Future<List<Conversation>> getList({
    int limit = 20,
    int offset = 0,
    int? type,
  }) async => conversations;

  @override
  Future<Conversation> getById(String id) async =>
      conversations.firstWhere((conversation) => conversation.id == id);

  @override
  Future<Conversation> getPrivateByPeerId(int peerUserId) async => conversations
      .firstWhere((conversation) => conversation.peerUserId == '$peerUserId');

  @override
  Future<void> hideFromList(String id) async {
    hiddenIds.add(id);
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
  }) => throw UnimplementedError();
}
