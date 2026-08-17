import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'group_list_state.dart';

class GroupListCubit extends Cubit<GroupListState> {
  GroupListCubit({
    required ConversationRepository repository,
    this.pageSize = 20,
  }) : _repository = repository,
       super(GroupListState());

  final ConversationRepository _repository;
  final int pageSize;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final groups = await _repository.getList(
        type: 1,
        limit: pageSize,
        offset: 0,
      );
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          groups: groups,
          isLoading: false,
          hasMore: groups.length == pageSize,
        ),
      );
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(state.copyWith(isLoading: false, errorMessage: '群聊列表加载失败'));
    }
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true, clearError: true));
    try {
      final next = await _repository.getList(
        type: 1,
        limit: pageSize,
        offset: state.groups.length,
      );
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          groups: [...state.groups, ...next],
          isLoadingMore: false,
          hasMore: next.length == pageSize,
        ),
      );
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(state.copyWith(isLoadingMore: false, errorMessage: '更多群聊加载失败'));
    }
  }

  void updateQuery(String value) {
    emit(state.copyWith(query: value, clearError: true));
  }
}
