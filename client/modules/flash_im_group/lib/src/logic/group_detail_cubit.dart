import 'dart:async';

import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/group_detail.dart';
import '../data/group_repository.dart';
import 'group_detail_state.dart';

class GroupDetailCubit extends Cubit<GroupDetailState> {
  GroupDetailCubit({
    required GroupRepository repository,
    required String groupId,
    WsClient? wsClient,
  }) : _repository = repository,
       _groupId = groupId,
       super(const GroupDetailState()) {
    _groupInfoSubscription = wsClient?.groupInfoUpdateStream.listen(
      _applyGroupInfoUpdate,
    );
  }

  final GroupRepository _repository;
  final String _groupId;
  StreamSubscription<GroupInfoUpdateNotification>? _groupInfoSubscription;
  bool _isLeaving = false;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final detail = await _repository.getDetail(_groupId);
      if (!isClosed) {
        emit(
          state.copyWith(detail: detail, isLoading: false, clearError: true),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: _groupError(error, '群信息加载失败，请稍后重试'),
          ),
        );
      }
    }
  }

  Future<bool> updateName(String value) async {
    final name = value.trim();
    if (name.isEmpty || name.runes.length > 100 || state.isSaving) return false;
    return _save(
      () => _repository.updateName(_groupId, name),
      fallback: '群名称修改失败，请稍后重试',
    );
  }

  Future<bool> updateNickname(String value) async {
    final nickname = value.trim();
    if (nickname.isEmpty || nickname.runes.length > 50 || state.isSaving) {
      return false;
    }
    return _save(
      () => _repository.updateNickname(_groupId, nickname),
      fallback: '群昵称修改失败，请稍后重试',
    );
  }

  Future<bool> updateAnnouncement(String value) async {
    final announcement = value.trim();
    if (announcement.isEmpty ||
        announcement.runes.length > 2000 ||
        state.isSaving) {
      return false;
    }
    return _save(
      () => _repository.updateAnnouncement(_groupId, announcement),
      fallback: '群公告发布失败，请稍后重试',
    );
  }

  Future<bool> transferOwner(int memberId) async {
    if (!state.isOwner || state.isSaving) return false;
    return _save(
      () => _repository.transferOwner(_groupId, memberId),
      fallback: '群主转让失败，请稍后重试',
    );
  }

  Future<bool> updateSettings(bool required) async {
    if (state.isSaving) return false;
    return _save(
      () =>
          _repository.updateSettings(_groupId, joinApprovalRequired: required),
      fallback: '邀请确认设置失败，请稍后重试',
    );
  }

  Future<bool> addMembers(List<int> memberIds) => _save(
    () => _repository.addMembers(_groupId, memberIds),
    fallback: '添加群成员失败，请稍后重试',
  );

  Future<bool> removeMember(int memberId) => _save(
    () => _repository.removeMember(_groupId, memberId),
    fallback: '删除群成员失败，请稍后重试',
  );

  Future<bool> inviteMembers(List<int> memberIds) async {
    if (state.isSaving) return false;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repository.inviteMembers(_groupId, memberIds);
      if (!isClosed) emit(state.copyWith(isSaving: false, clearError: true));
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: _groupError(error, '发送群邀请失败，请稍后重试'),
          ),
        );
      }
      return false;
    }
  }

  void toggleDeleteMode() {
    if (!state.isOwner || state.isSaving) return;
    emit(state.copyWith(isDeleteMode: !state.isDeleteMode, clearError: true));
  }

  Future<bool> dissolveGroup() async {
    if (!state.isOwner || state.isSaving) return false;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repository.dissolveGroup(_groupId);
      if (!isClosed) {
        emit(
          state.copyWith(isSaving: false, isDissolved: true, clearError: true),
        );
      }
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: _groupError(error, '解散群聊失败，请稍后重试'),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> leaveGroup() async {
    if (state.isOwner || state.isSaving) return false;
    _isLeaving = true;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repository.leaveGroup(_groupId);
      if (!isClosed) {
        emit(state.copyWith(isSaving: false, isLeft: true, clearError: true));
      }
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: _groupError(error, '退出群聊失败，请稍后重试'),
          ),
        );
      }
      return false;
    } finally {
      _isLeaving = false;
    }
  }

  void _applyGroupInfoUpdate(GroupInfoUpdateNotification update) {
    if (update.conversationId != _groupId || isClosed) return;
    if (!update.membershipActive) {
      emit(
        state.copyWith(
          isLeft: _isLeaving,
          isRemoved: !_isLeaving,
          isSaving: false,
          clearError: true,
        ),
      );
      return;
    }
    if (update.isDissolved) {
      emit(
        state.copyWith(isDissolved: true, isSaving: false, clearError: true),
      );
      return;
    }
    final detail = state.detail;
    if (detail == null ||
        const {
          'members_added',
          'member_removed',
          'member_left',
          'owner_transferred',
          'member_nickname_updated',
        }.contains(update.changeType)) {
      unawaited(load());
      return;
    }
    emit(
      state.copyWith(
        detail: detail.copyWith(
          name: update.name,
          avatar: update.avatar,
          ownerId: update.ownerId.toInt(),
          announcement: update.announcement,
          announcementUpdatedAt: DateTime.tryParse(
            update.announcementUpdatedAt,
          )?.toLocal(),
          announcementUpdatedBy: update.announcementUpdatedBy.toInt() == 0
              ? null
              : update.announcementUpdatedBy.toInt(),
          currentUserRole: update.currentUserRole,
          memberCount: update.memberCount,
          isDissolved: update.isDissolved,
        ),
        clearError: true,
      ),
    );
  }

  Future<bool> _save(
    Future<GroupDetail> Function() request, {
    required String fallback,
  }) async {
    if (state.isSaving) return false;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final detail = await request();
      if (!isClosed) {
        emit(
          state.copyWith(
            detail: detail,
            isSaving: false,
            isDeleteMode: false,
            clearError: true,
          ),
        );
      }
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: _groupError(error, fallback),
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _groupInfoSubscription?.cancel();
    return super.close();
  }
}

String _groupError(Object error, String fallback) {
  if (error is GroupRequestException) {
    return switch (error.serverMessage) {
      'group not found' => '群聊不存在或你已不在群内',
      'group operation is not allowed' => '当前没有执行此操作的权限',
      'invalid group members' => '只能选择自己的好友加入群聊',
      'group member already exists' => '选择的好友已在群聊中',
      'group member limit reached' => '群成员已达上限',
      'group owner cannot be removed' => '不能删除群主',
      'group owner cannot leave' => '群主请先转让群主或解散群聊',
      'new owner must be another member' => '请选择其他成员作为新群主',
      'new owner must be an active member' => '新群主必须是当前群成员',
      'invalid group announcement' => '群公告需为 1～2000 字',
      'invalid group nickname' => '群昵称需为 1～50 字',
      'group invitation delivery failed' => '部分群邀请发送失败，请重试',
      _ => fallback,
    };
  }
  return fallback;
}
