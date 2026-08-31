import 'dart:async';

import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/group_discovery.dart';
import '../data/group_repository.dart';
import 'group_notification_state.dart';

class GroupNotificationCubit extends Cubit<GroupNotificationState> {
  GroupNotificationCubit({
    required GroupRepository repository,
    required WsClient wsClient,
  }) : _repository = repository,
       super(const GroupNotificationState()) {
    _subscription = wsClient.groupJoinRequestStream.listen(_handleEvent);
  }

  final GroupRepository _repository;
  late final StreamSubscription<GroupJoinRequestNotification> _subscription;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final result = await _repository.getJoinRequests();
      if (!isClosed) {
        emit(
          state.copyWith(
            requests: result.requests,
            pendingCount: result.pendingCount,
            isLoading: false,
            errorMessage: null,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, errorMessage: '群通知加载失败，请稍后重试'));
      }
    }
  }

  Future<bool> handle(
    GroupJoinRequest request, {
    required bool approved,
  }) async {
    if (!request.isPending || state.handlingRequestId != null) return false;
    emit(state.copyWith(handlingRequestId: request.id, errorMessage: null));
    try {
      final handled = await _repository.handleJoinRequest(
        request.conversationId,
        request.id,
        approved: approved,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            requests: state.requests
                .map((item) => item.id == handled.id ? handled : item)
                .toList(growable: false),
            pendingCount: state.pendingCount > 0 ? state.pendingCount - 1 : 0,
            handlingRequestId: null,
            errorMessage: null,
          ),
        );
      }
      return true;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            handlingRequestId: null,
            errorMessage: '入群申请处理失败，请稍后重试',
          ),
        );
      }
      return false;
    }
  }

  void clearError() => emit(state.copyWith(errorMessage: null));

  void _handleEvent(GroupJoinRequestNotification event) {
    if (event.status != 0 || isClosed) return;
    final request = GroupJoinRequest.fromNotification(event);
    final existingIndex = state.requests.indexWhere(
      (item) => item.id == request.id,
    );
    if (existingIndex >= 0) return;
    emit(
      state.copyWith(
        requests: [request, ...state.requests],
        pendingCount: state.pendingCount + 1,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
