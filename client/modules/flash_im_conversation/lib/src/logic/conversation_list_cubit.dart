import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/conversation.dart';
import '../data/conversation_repository.dart';
import 'conversation_list_state.dart';

class ConversationListCubit extends Cubit<ConversationListState> {
  ConversationListCubit({
    required ConversationRepository repository,
    WsClient? wsClient,
    int pageSize = 20,
  }) : _repository = repository,
       _wsClient = wsClient,
       _pageSize = pageSize,
       super(const ConversationListInitial()) {
    _conversationUpdateSubscription = _wsClient?.conversationUpdateStream
        .listen(applyConversationUpdate);
    _groupInfoUpdateSubscription = _wsClient?.groupInfoUpdateStream.listen(
      applyGroupInfoUpdate,
    );
  }

  final ConversationRepository _repository;
  final WsClient? _wsClient;
  final int _pageSize;
  bool _isLoadingMore = false;
  StreamSubscription<ConversationUpdate>? _conversationUpdateSubscription;
  StreamSubscription<GroupInfoUpdateNotification>? _groupInfoUpdateSubscription;

  Future<void> loadConversations() async {
    emit(const ConversationListLoading());
    try {
      final conversations = await _repository.getList(
        limit: _pageSize,
        offset: 0,
      );
      emit(
        ConversationListLoaded(
          conversations: conversations,
          hasMore: conversations.length == _pageSize,
        ),
      );
    } catch (error) {
      emit(ConversationListError(_readErrorMessage(error)));
    }
  }

  Future<void> refresh() async {
    try {
      final conversations = await _repository.getList(
        limit: _pageSize,
        offset: 0,
      );
      emit(
        ConversationListLoaded(
          conversations: conversations,
          hasMore: conversations.length == _pageSize,
        ),
      );
    } catch (error) {
      final current = state;
      if (current is ConversationListLoaded) {
        emit(
          current.copyWith(
            isLoadingMore: false,
            loadMoreError: _readErrorMessage(error),
          ),
        );
        return;
      }
      emit(ConversationListError(_readErrorMessage(error)));
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! ConversationListLoaded ||
        !current.hasMore ||
        _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    emit(current.copyWith(isLoadingMore: true, loadMoreError: null));
    try {
      final nextPage = await _repository.getList(
        limit: _pageSize,
        offset: current.conversations.length,
      );
      emit(
        ConversationListLoaded(
          conversations: [...current.conversations, ...nextPage],
          hasMore: nextPage.length == _pageSize,
        ),
      );
    } catch (error) {
      emit(
        current.copyWith(
          isLoadingMore: false,
          loadMoreError: _readErrorMessage(error),
        ),
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    markConversationReadLocally(conversationId);
    try {
      await _repository.markRead(conversationId);
    } catch (_) {
      // Local read state should not bounce while the user is inside the chat.
    }
  }

  void markConversationReadLocally(String conversationId) {
    final current = state;
    if (current is! ConversationListLoaded) {
      return;
    }

    emit(
      current.copyWith(
        conversations: current.conversations
            .map(
              (conversation) => conversation.id == conversationId
                  ? conversation.copyWith(unreadCount: 0)
                  : conversation,
            )
            .toList(growable: false),
      ),
    );
  }

  void applyConversationUpdate(ConversationUpdate update) {
    final current = state;
    if (current is! ConversationListLoaded || update.conversationId.isEmpty) {
      return;
    }

    final parsedTime = DateTime.tryParse(update.lastMessageAt)?.toLocal();
    final conversations = [...current.conversations];
    final index = conversations.indexWhere(
      (conversation) => conversation.id == update.conversationId,
    );
    if (index >= 0) {
      conversations[index] = conversations[index].copyWith(
        lastMessagePreview: update.lastMessagePreview,
        lastMessageAt: parsedTime,
        unreadCount: update.unreadCount,
      );
    } else {
      conversations.insert(
        0,
        Conversation.placeholder(
          id: update.conversationId,
          lastMessagePreview: update.lastMessagePreview,
          lastMessageAt: parsedTime ?? DateTime.now(),
          unreadCount: update.unreadCount,
        ),
      );
      unawaited(_hydrateConversation(update.conversationId));
    }

    conversations.sort((left, right) {
      return right.displayTime.compareTo(left.displayTime);
    });
    emit(
      current.copyWith(
        conversations: conversations,
        totalUnread: update.totalUnread > 0 ? update.totalUnread : null,
      ),
    );
  }

  void applyGroupInfoUpdate(GroupInfoUpdateNotification update) {
    final current = state;
    if (current is! ConversationListLoaded || update.conversationId.isEmpty) {
      return;
    }
    final conversations = [...current.conversations];
    final index = conversations.indexWhere(
      (conversation) => conversation.id == update.conversationId,
    );
    if (!update.membershipActive) {
      if (index >= 0) {
        conversations.removeAt(index);
        emit(current.copyWith(conversations: conversations));
      }
      return;
    }

    if (index >= 0) {
      conversations[index] = conversations[index].copyWith(
        type: 1,
        name: update.name,
        avatar: update.avatar,
        ownerId: update.ownerId.toString(),
        isDissolved: update.isDissolved,
      );
    } else {
      conversations.insert(
        0,
        Conversation(
          id: update.conversationId,
          type: 1,
          name: update.name,
          avatar: update.avatar,
          ownerId: update.ownerId.toString(),
          unreadCount: 0,
          isDissolved: update.isDissolved,
          createdAt: DateTime.now(),
        ),
      );
      unawaited(_hydrateConversation(update.conversationId));
    }
    emit(current.copyWith(conversations: conversations));
  }

  Future<void> _hydrateConversation(String conversationId) async {
    try {
      final detail = await _repository.getById(conversationId);
      final current = state;
      if (current is! ConversationListLoaded) {
        return;
      }
      emit(
        current.copyWith(
          conversations: current.conversations
              .map(
                (conversation) =>
                    conversation.id == conversationId ? detail : conversation,
              )
              .toList(growable: false),
        ),
      );
    } catch (_) {
      // Placeholder data is good enough until the next refresh.
    }
  }

  @override
  Future<void> close() async {
    await _conversationUpdateSubscription?.cancel();
    await _groupInfoUpdateSubscription?.cancel();
    return super.close();
  }
}

String _readErrorMessage(Object error) {
  if (error is DioException) {
    return '会话列表加载失败，请稍后重试';
  }
  if (error is FormatException) {
    return '会话数据格式异常';
  }
  return '会话列表加载失败';
}
