import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flash_im_core/flash_im_core.dart' as im_core;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_repository.dart';
import '../data/friend_request.dart';
import '../data/friend_user.dart';
import 'friend_state.dart';

class FriendCubit extends Cubit<FriendState> {
  FriendCubit({
    required FriendRepository repository,
    im_core.WsClient? wsClient,
  }) : _repository = repository,
       super(const FriendState()) {
    _requestSubscription = wsClient?.friendRequestStream.listen(
      _handleFriendRequest,
    );
    _acceptedSubscription = wsClient?.friendAcceptedStream.listen(
      _handleFriendAccepted,
    );
    _removedSubscription = wsClient?.friendRemovedStream.listen(
      _handleFriendRemoved,
    );
  }

  final FriendRepository _repository;
  StreamSubscription<im_core.FriendRequestEvent>? _requestSubscription;
  StreamSubscription<im_core.FriendAcceptedEvent>? _acceptedSubscription;
  StreamSubscription<im_core.FriendRemovedEvent>? _removedSubscription;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _loadAll();
  }

  Future<void> refresh() => _loadAll();

  Future<void> _loadAll() async {
    try {
      final values = await Future.wait<Object>([
        _repository.getFriends(),
        _repository.getReceivedRequests(status: 'all'),
        _repository.getSentRequests(status: 'all'),
      ]);
      emit(
        state.copyWith(
          friends: values[0] as List<FriendUser>,
          receivedRequests: values[1] as List<FriendRequest>,
          sentRequests: values[2] as List<FriendRequest>,
          isLoading: false,
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _readErrorMessage(error, '通讯录加载失败'),
        ),
      );
    }
  }

  Future<void> search(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      emit(
        state.copyWith(
          searchResults: const [],
          isSearching: false,
          errorMessage: null,
        ),
      );
      return;
    }

    emit(state.copyWith(isSearching: true, errorMessage: null));
    try {
      final results = await _repository.searchUsers(keyword);
      emit(
        state.copyWith(
          searchResults: results,
          isSearching: false,
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          searchResults: const [],
          isSearching: false,
          errorMessage: _readErrorMessage(error, '搜索失败'),
        ),
      );
    }
  }

  Future<bool> sendRequest(FriendUser user, String message) async {
    if (state.processingUserIds.contains(user.accountId)) {
      return false;
    }
    final processing = {...state.processingUserIds, user.accountId};
    emit(state.copyWith(processingUserIds: processing, actionMessage: null));
    try {
      await _repository.sendRequest(
        toUserId: user.accountId,
        message: message.trim(),
      );
      final sentRequests = await _reloadSentRequestsOrKeepCurrent();
      _replaceUserRelation(user.accountId, 'pending_sent');
      emit(
        state.copyWith(
          sentRequests: sentRequests,
          processingUserIds: {...state.processingUserIds}
            ..remove(user.accountId),
          actionMessage: '好友申请已发送',
        ),
      );
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          processingUserIds: {...state.processingUserIds}
            ..remove(user.accountId),
          actionMessage: _readErrorMessage(error, '好友申请发送失败'),
        ),
      );
      return false;
    }
  }

  Future<FriendAcceptResult?> acceptRequest(FriendRequest request) async {
    if (state.processingRequestIds.contains(request.id)) {
      return null;
    }
    _setRequestProcessing(request.id, true);
    try {
      final result = await _repository.acceptRequest(request.id);
      emit(
        state.copyWith(
          friends: _upsertFriend(
            state.friends,
            result.friend.copyWith(relationStatus: 'friend'),
          ),
          receivedRequests: _markRequestsForUserAccepted(
            state.receivedRequests,
            requestId: request.id,
            accountId: result.friend.accountId,
          ),
          sentRequests: _markRequestsForUserAccepted(
            state.sentRequests,
            requestId: request.id,
            accountId: result.friend.accountId,
          ),
          processingRequestIds: {...state.processingRequestIds}
            ..remove(request.id),
          actionMessage: '已添加 ${result.friend.displayName}',
        ),
      );
      return result;
    } catch (error) {
      _finishRequestWithError(request.id, error, '接受好友申请失败');
      return null;
    }
  }

  Future<bool> rejectRequest(FriendRequest request) async {
    if (state.processingRequestIds.contains(request.id)) {
      return false;
    }
    _setRequestProcessing(request.id, true);
    try {
      await _repository.rejectRequest(request.id);
      emit(
        state.copyWith(
          receivedRequests: _replaceRequestStatus(
            state.receivedRequests,
            request.id,
            'rejected',
          ),
          processingRequestIds: {...state.processingRequestIds}
            ..remove(request.id),
          actionMessage: '已拒绝好友申请',
        ),
      );
      return true;
    } catch (error) {
      _finishRequestWithError(request.id, error, '拒绝好友申请失败');
      return false;
    }
  }

  Future<bool> removeFriend(FriendUser friend) async {
    if (state.processingUserIds.contains(friend.accountId)) {
      return false;
    }
    emit(
      state.copyWith(
        processingUserIds: {...state.processingUserIds, friend.accountId},
        actionMessage: null,
      ),
    );
    try {
      await _repository.removeFriend(friend.accountId);
      emit(
        state.copyWith(
          friends: state.friends
              .where((item) => item.accountId != friend.accountId)
              .toList(growable: false),
          searchResults: state.searchResults
              .map(
                (item) => item.accountId == friend.accountId
                    ? item.copyWith(relationStatus: 'none')
                    : item,
              )
              .toList(growable: false),
          processingUserIds: {...state.processingUserIds}
            ..remove(friend.accountId),
          actionMessage: '已删除好友',
        ),
      );
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          processingUserIds: {...state.processingUserIds}
            ..remove(friend.accountId),
          actionMessage: _readErrorMessage(error, '删除好友失败'),
        ),
      );
      return false;
    }
  }

  void clearActionMessage() {
    emit(state.copyWith(actionMessage: null));
  }

  void _setRequestProcessing(String requestId, bool processing) {
    final ids = {...state.processingRequestIds};
    processing ? ids.add(requestId) : ids.remove(requestId);
    emit(state.copyWith(processingRequestIds: ids, actionMessage: null));
  }

  void _finishRequestWithError(
    String requestId,
    Object error,
    String fallback,
  ) {
    emit(
      state.copyWith(
        processingRequestIds: {...state.processingRequestIds}
          ..remove(requestId),
        actionMessage: _readErrorMessage(error, fallback),
      ),
    );
  }

  void _replaceUserRelation(int accountId, String relationStatus) {
    emit(
      state.copyWith(
        searchResults: state.searchResults
            .map(
              (item) => item.accountId == accountId
                  ? item.copyWith(relationStatus: relationStatus)
                  : item,
            )
            .toList(growable: false),
      ),
    );
  }

  Future<List<FriendRequest>> _reloadSentRequestsOrKeepCurrent() async {
    try {
      return await _repository.getSentRequests(status: 'all');
    } catch (_) {
      return state.sentRequests;
    }
  }

  void _handleFriendRequest(im_core.FriendRequestEvent event) {
    if (!event.hasFromUser() || event.requestId.isEmpty) {
      return;
    }
    final request = FriendRequest(
      id: event.requestId,
      fromUser: _fromProto(event.fromUser, relationStatus: 'pending_received'),
      message: event.message,
      status: 'pending',
      createdAt:
          DateTime.tryParse(event.createdAt)?.toLocal() ?? DateTime.now(),
    );
    final requests = [...state.receivedRequests];
    final index = requests.indexWhere((item) => item.id == request.id);
    if (index >= 0) {
      requests[index] = request;
    } else {
      requests.insert(0, request);
    }
    emit(state.copyWith(receivedRequests: requests));
  }

  void _handleFriendAccepted(im_core.FriendAcceptedEvent event) {
    if (!event.hasFriend()) {
      return;
    }
    final friend = _fromProto(event.friend, relationStatus: 'friend');
    emit(
      state.copyWith(
        friends: _upsertFriend(state.friends, friend),
        receivedRequests: _markRequestsForUserAccepted(
          state.receivedRequests,
          requestId: event.requestId,
          accountId: friend.accountId,
        ),
        sentRequests: _markRequestsForUserAccepted(
          state.sentRequests,
          requestId: event.requestId,
          accountId: friend.accountId,
        ),
      ),
    );
  }

  void _handleFriendRemoved(im_core.FriendRemovedEvent event) {
    if (!event.hasFriend()) {
      return;
    }
    final accountId = event.friend.accountId.toInt();
    emit(
      state.copyWith(
        friends: state.friends
            .where((item) => item.accountId != accountId)
            .toList(growable: false),
      ),
    );
  }

  FriendUser _fromProto(
    im_core.FriendUser user, {
    required String relationStatus,
  }) {
    return FriendUser(
      accountId: user.accountId.toInt(),
      nickname: user.nickname,
      avatar: user.avatar,
      signature: user.signature,
      flashId: user.flashId.isEmpty ? null : user.flashId,
      relationStatus: relationStatus,
    );
  }

  @override
  Future<void> close() async {
    await _requestSubscription?.cancel();
    await _acceptedSubscription?.cancel();
    await _removedSubscription?.cancel();
    return super.close();
  }
}

List<FriendUser> _upsertFriend(List<FriendUser> current, FriendUser friend) {
  final friends = [...current];
  final index = friends.indexWhere(
    (item) => item.accountId == friend.accountId,
  );
  if (index >= 0) {
    friends[index] = friend;
  } else {
    friends.add(friend);
  }
  return friends;
}

List<FriendRequest> _replaceRequestStatus(
  List<FriendRequest> current,
  String requestId,
  String status,
) {
  return current
      .map(
        (request) => request.id == requestId
            ? request.copyWith(status: status)
            : request,
      )
      .toList(growable: false);
}

List<FriendRequest> _markRequestsForUserAccepted(
  List<FriendRequest> current, {
  required String requestId,
  required int accountId,
}) {
  return current
      .map(
        (request) =>
            (requestId.isNotEmpty && request.id == requestId) ||
                (request.isPending && request.otherUser.accountId == accountId)
            ? request.copyWith(status: 'accepted')
            : request,
      )
      .toList(growable: false);
}

String _readErrorMessage(Object error, String fallback) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) {
      final message = (data['error'] as String).trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
  }
  if (error is FormatException) {
    return '好友数据格式异常';
  }
  return fallback;
}
