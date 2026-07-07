import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/conversation_repository.dart';
import 'conversation_list_state.dart';

class ConversationListCubit extends Cubit<ConversationListState> {
  ConversationListCubit({
    required ConversationRepository repository,
    int pageSize = 20,
  }) : _repository = repository,
       _pageSize = pageSize,
       super(const ConversationListInitial());

  final ConversationRepository _repository;
  final int _pageSize;
  bool _isLoadingMore = false;

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
