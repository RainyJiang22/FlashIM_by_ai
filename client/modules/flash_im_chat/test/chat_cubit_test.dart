import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final conversation = Conversation(
    id: 'c1',
    type: 0,
    peerUserId: '2',
    peerNickname: '朱红',
    unreadCount: 0,
    createdAt: DateTime(2026, 4, 2),
  );
  final history = Message(
    id: 'm1',
    conversationId: 'c1',
    senderId: '2',
    senderName: '朱红',
    seq: 1,
    content: 'hello',
    status: MessageStatus.sent,
    createdAt: DateTime(2026, 4, 2, 9),
  );

  blocTest<ChatCubit, ChatState>(
    'loadMessages emits loaded messages',
    build: () => ChatCubit(
      repository: _FakeMessageRepository(messages: [history]),
      wsClient: _FakeWsClient(),
      conversation: conversation,
      currentUserId: '1',
    ),
    act: (cubit) => cubit.loadMessages(),
    expect: () => [
      const ChatLoading(),
      ChatLoaded(messages: [history], hasMore: false),
    ],
  );

  blocTest<ChatCubit, ChatState>(
    'sendText appends sending message',
    build: () {
      return ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: _FakeWsClient(),
        conversation: conversation,
        currentUserId: '1',
      );
    },
    seed: () => const ChatLoaded(messages: [], hasMore: false),
    act: (cubit) => cubit.sendText('hi'),
    expect: () => [isA<ChatLoaded>()],
    verify: (cubit) {
      final state = cubit.state as ChatLoaded;
      expect(state.messages.single.status, MessageStatus.sending);
    },
  );

  late _FakeWsClient ackWsClient;
  blocTest<ChatCubit, ChatState>(
    'message ack marks first pending message as sent',
    build: () {
      ackWsClient = _FakeWsClient();
      return ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: ackWsClient,
        conversation: conversation,
        currentUserId: '1',
      );
    },
    seed: () => const ChatLoaded(messages: [], hasMore: false),
    act: (cubit) {
      cubit.sendText('hi');
      ackWsClient.emitAck(MessageAck(messageId: 'server-m1', seq: 8));
    },
    expect: () => [isA<ChatLoaded>(), isA<ChatLoaded>()],
    verify: (cubit) {
      final state = cubit.state as ChatLoaded;
      expect(state.messages.single.id, 'server-m1');
      expect(state.messages.single.seq, 8);
      expect(state.messages.single.status, MessageStatus.sent);
    },
  );

  late _FakeWsClient incomingWsClient;
  blocTest<ChatCubit, ChatState>(
    'incoming message from current conversation is appended',
    build: () {
      incomingWsClient = _FakeWsClient();
      return ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: incomingWsClient,
        conversation: conversation,
        currentUserId: '1',
      );
    },
    seed: () => ChatLoaded(messages: [history], hasMore: false),
    act: (cubit) {
      incomingWsClient.emitMessage(
        ChatMessage(
          id: 'm2',
          conversationId: 'c1',
          senderId: 2,
          seq: 2,
          content: 'new',
          createdAt: '2026-04-02T09:02:00Z',
        ),
      );
    },
    expect: () => [isA<ChatLoaded>()],
    verify: (cubit) {
      final state = cubit.state as ChatLoaded;
      expect(state.messages.map((message) => message.id), ['m1', 'm2']);
    },
  );

  late _FakeWsClient ignoredWsClient;
  blocTest<ChatCubit, ChatState>(
    'incoming message from another conversation is ignored',
    build: () {
      ignoredWsClient = _FakeWsClient();
      return ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: ignoredWsClient,
        conversation: conversation,
        currentUserId: '1',
      );
    },
    seed: () => ChatLoaded(messages: [history], hasMore: false),
    act: (cubit) {
      ignoredWsClient.emitMessage(
        ChatMessage(id: 'm2', conversationId: 'other', senderId: 2),
      );
    },
    expect: () => const <ChatState>[],
  );
}

class _FakeMessageRepository implements MessageRepository {
  const _FakeMessageRepository({required this.messages});

  final List<Message> messages;

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  }) async {
    return messages;
  }
}

class _FakeWsClient extends WsClient {
  _FakeWsClient()
    : _chatMessages = StreamController<ChatMessage>.broadcast(sync: true),
      _messageAcks = StreamController<MessageAck>.broadcast(sync: true),
      super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
        tokenProvider: () => null,
      );

  final StreamController<ChatMessage> _chatMessages;
  final StreamController<MessageAck> _messageAcks;

  @override
  Stream<ChatMessage> get chatMessageStream => _chatMessages.stream;

  @override
  Stream<MessageAck> get messageAckStream => _messageAcks.stream;

  @override
  void sendChatMessage(SendMessageRequest request) {}

  void emitMessage(ChatMessage message) {
    _chatMessages.add(message);
  }

  void emitAck(MessageAck ack) {
    _messageAcks.add(ack);
  }

  @override
  Future<void> dispose() async {
    await _chatMessages.close();
    await _messageAcks.close();
    await super.dispose();
  }
}
