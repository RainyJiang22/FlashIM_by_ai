import 'dart:async';

import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/group_discovery.dart';
import '../data/group_repository.dart';
import 'group_search_state.dart';

class GroupSearchCubit extends Cubit<GroupSearchState> {
  GroupSearchCubit({required GroupRepository repository, WsClient? wsClient})
    : _repository = repository,
      super(const GroupSearchState()) {
    _joinSubscription = wsClient?.groupJoinRequestStream.listen(
      _handleJoinRequestEvent,
    );
  }

  final GroupRepository _repository;
  StreamSubscription<GroupJoinRequestNotification>? _joinSubscription;
  int _searchGeneration = 0;

  Future<void> search(String value) async {
    final keyword = value.trim();
    final generation = ++_searchGeneration;
    if (keyword.isEmpty) {
      emit(const GroupSearchState());
      return;
    }
    emit(
      state.copyWith(
        keyword: keyword,
        isLoading: true,
        errorMessage: null,
        lastJoinResult: null,
      ),
    );
    try {
      final items = await _repository.searchGroups(keyword);
      if (!isClosed && generation == _searchGeneration) {
        emit(
          state.copyWith(
            keyword: keyword,
            items: items,
            isLoading: false,
            errorMessage: null,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && generation == _searchGeneration) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: _groupSearchError(error),
          ),
        );
      }
    }
  }

  Future<bool> join(GroupSearchItem item, {String? message}) async {
    if (state.actionGroupId != null || item.isMember) return false;
    emit(
      state.copyWith(
        actionGroupId: item.conversationId,
        errorMessage: null,
        lastJoinResult: null,
      ),
    );
    try {
      final result = await _repository.joinGroup(
        item.conversationId,
        message: message,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            items: _replaceItem(
              item.conversationId,
              (current) => current.copyWith(
                isMember: result.autoApproved,
                hasPendingRequest: !result.autoApproved,
              ),
            ),
            actionGroupId: null,
            lastJoinResult: result,
          ),
        );
      }
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            actionGroupId: null,
            errorMessage: _groupSearchError(error),
          ),
        );
      }
      return false;
    }
  }

  void clearFeedback() {
    emit(state.copyWith(errorMessage: null, lastJoinResult: null));
  }

  void _handleJoinRequestEvent(GroupJoinRequestNotification event) {
    if (event.status == 0 || isClosed) return;
    emit(
      state.copyWith(
        items: _replaceItem(
          event.conversationId,
          (current) => current.copyWith(
            isMember: event.status == 1,
            hasPendingRequest: false,
          ),
        ),
      ),
    );
  }

  List<GroupSearchItem> _replaceItem(
    String groupId,
    GroupSearchItem Function(GroupSearchItem item) update,
  ) => state.items
      .map((item) => item.conversationId == groupId ? update(item) : item)
      .toList(growable: false);

  @override
  Future<void> close() async {
    await _joinSubscription?.cancel();
    return super.close();
  }
}

String _groupSearchError(Object error) {
  if (error is GroupRequestException) {
    return switch (error.serverMessage) {
      'already a group member' => '你已经是该群成员',
      'group join request already pending' => '入群申请已发送，请等待群主处理',
      'group member limit reached' => '该群成员已满',
      'group not found' => '群聊不存在或已解散',
      'invalid join request message' => '申请留言不能超过 200 个字符',
      _ => '操作失败，请稍后重试',
    };
  }
  return '网络异常，请稍后重试';
}
