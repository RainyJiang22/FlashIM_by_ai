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
}

class _ConversationRepository implements ConversationRepository {
  _ConversationRepository(this.conversations);

  final List<Conversation> conversations;

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
  Future<void> markRead(String id) async {}

  @override
  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
  }) => throw UnimplementedError();
}
