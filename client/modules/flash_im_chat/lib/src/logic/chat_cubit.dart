import 'dart:async';
import 'dart:collection';

import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/message.dart';
import '../data/message_repository.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required MessageRepository repository,
    required WsClient wsClient,
    required Conversation conversation,
    required String currentUserId,
  }) : _repository = repository,
       _wsClient = wsClient,
       _conversation = conversation,
       _currentUserId = currentUserId,
       super(const ChatInitial()) {
    _chatMessageSubscription = _wsClient.chatMessageStream.listen(
      _handleIncomingMessage,
    );
    _messageAckSubscription = _wsClient.messageAckStream.listen(_handleAck);
  }

  static const _pageSize = 50;
  static const _ackTimeout = Duration(seconds: 12);

  final MessageRepository _repository;
  final WsClient _wsClient;
  final Conversation _conversation;
  final String _currentUserId;
  final Queue<String> _pendingLocalIds = Queue<String>();
  final Map<String, Timer> _ackTimers = {};
  StreamSubscription<ChatMessage>? _chatMessageSubscription;
  StreamSubscription<MessageAck>? _messageAckSubscription;

  Future<void> loadMessages() async {
    emit(const ChatLoading());
    try {
      final messages = await _repository.getMessages(
        conversationId: _conversation.id,
        limit: _pageSize,
      );
      emit(
        ChatLoaded(messages: messages, hasMore: messages.length == _pageSize),
      );
    } catch (_) {
      emit(const ChatError('消息加载失败，请稍后重试'));
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! ChatLoaded || current.isLoadingMore || !current.hasMore) {
      return;
    }
    final beforeSeq = current.messages
        .where((message) => message.seq > 0)
        .map((message) => message.seq)
        .fold<int?>(null, (min, seq) => min == null || seq < min ? seq : min);
    if (beforeSeq == null) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true, errorMessage: null));
    try {
      final older = await _repository.getMessages(
        conversationId: _conversation.id,
        beforeSeq: beforeSeq,
        limit: _pageSize,
      );
      emit(
        current.copyWith(
          messages: _sortMessages([...older, ...current.messages]),
          hasMore: older.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(current.copyWith(isLoadingMore: false, errorMessage: '更多消息加载失败'));
    }
  }

  void sendText(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final current = state;
    if (current is! ChatLoaded) {
      return;
    }

    final local = Message.local(
      conversationId: _conversation.id,
      senderId: _currentUserId,
      senderName: '我',
      content: trimmed,
    );
    _pendingLocalIds.add(local.id);
    emit(
      current.copyWith(messages: _sortMessages([...current.messages, local])),
    );
    _wsClient.sendChatMessage(
      SendMessageRequest(
        conversationId: _conversation.id,
        type: 0,
        content: trimmed,
        clientId: local.id,
      ),
    );
    _ackTimers[local.id] = Timer(_ackTimeout, () => _markFailed(local.id));
  }

  void _handleAck(MessageAck ack) {
    final current = state;
    if (current is! ChatLoaded || _pendingLocalIds.isEmpty) {
      return;
    }
    final localId = _pendingLocalIds.removeFirst();
    _ackTimers.remove(localId)?.cancel();
    emit(
      current.copyWith(
        messages: _sortMessages(
          current.messages
              .map(
                (message) => message.id == localId
                    ? message.copyWith(
                        id: ack.messageId,
                        seq: ack.seq,
                        status: MessageStatus.sent,
                      )
                    : message,
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  void _handleIncomingMessage(ChatMessage message) {
    final current = state;
    if (current is! ChatLoaded ||
        message.conversationId != _conversation.id ||
        '${message.senderId}' == _currentUserId) {
      return;
    }
    final incoming = Message.fromChatMessage(message);
    if (current.messages.any((item) => item.id == incoming.id)) {
      return;
    }
    emit(
      current.copyWith(
        messages: _sortMessages([...current.messages, incoming]),
      ),
    );
  }

  void _markFailed(String localId) {
    final current = state;
    if (current is! ChatLoaded) {
      return;
    }
    _pendingLocalIds.remove(localId);
    emit(
      current.copyWith(
        messages: current.messages
            .map(
              (message) => message.id == localId
                  ? message.copyWith(status: MessageStatus.failed)
                  : message,
            )
            .toList(growable: false),
      ),
    );
  }

  List<Message> _sortMessages(List<Message> messages) {
    messages.sort((left, right) {
      if (left.seq == 0 && right.seq != 0) {
        return 1;
      }
      if (right.seq == 0 && left.seq != 0) {
        return -1;
      }
      if (left.seq != right.seq) {
        return left.seq.compareTo(right.seq);
      }
      return left.createdAt.compareTo(right.createdAt);
    });
    return messages;
  }

  @override
  Future<void> close() async {
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    await _chatMessageSubscription?.cancel();
    await _messageAckSubscription?.cancel();
    return super.close();
  }
}
