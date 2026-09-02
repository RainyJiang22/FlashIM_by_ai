import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart' show WsClient;
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/group_detail.dart';
import '../data/group_repository.dart';
import '../logic/group_detail_cubit.dart';
import '../logic/group_detail_state.dart';
import 'group_member_picker_page.dart';
import 'group_announcement_page.dart';
import 'transfer_group_owner_page.dart';
import 'widgets/group_member_grid.dart';
import 'widgets/group_name_editor.dart';

class GroupDetailsPage extends StatelessWidget {
  const GroupDetailsPage({
    super.key,
    required this.conversation,
    this.wsClient,
  });

  final Conversation conversation;
  final WsClient? wsClient;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GroupDetailCubit(
        repository: context.read<GroupRepository>(),
        groupId: conversation.id,
        wsClient: wsClient,
      )..load(),
      child: _GroupDetailsView(conversation: conversation),
    );
  }
}

class _GroupDetailsView extends StatelessWidget {
  const _GroupDetailsView({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupDetailCubit, GroupDetailState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.isDissolved != current.isDissolved ||
          previous.isLeft != current.isLeft ||
          previous.isRemoved != current.isRemoved,
      listener: (context, state) {
        if (state.isDissolved) {
          final updated = state.detail
              ?.applyToConversation(conversation)
              .copyWith(isDissolved: true);
          Navigator.of(context).pop(GroupDetailsResult.dissolved(updated));
          return;
        }
        if (state.isLeft) {
          Navigator.of(context).pop(const GroupDetailsResult.left());
          return;
        }
        if (state.isRemoved) {
          Navigator.of(context).pop(const GroupDetailsResult.removed());
          return;
        }
        final message = state.errorMessage;
        if (message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        return PopScope<GroupDetailsResult>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _popUpdated(context, state.detail);
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('聊天信息'),
              leading: IconButton(
                onPressed: () => _popUpdated(context, state.detail),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
            ),
            backgroundColor: FlashPalette.background,
            body: _body(context, state),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, GroupDetailState state) {
    final detail = state.detail;
    if (state.isLoading && detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (detail == null) {
      return Center(
        child: FilledButton.icon(
          key: const Key('group-detail-retry'),
          onPressed: context.read<GroupDetailCubit>().load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重新加载'),
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              decoration: flashCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${detail.memberCount} 位群成员',
                      style: const TextStyle(
                        color: FlashPalette.secondaryInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GroupMemberGrid(
                    members: detail.members,
                    isOwner: detail.isOwner,
                    isDeleteMode: state.isDeleteMode,
                    onAdd: () => _pickMembers(context, detail),
                    onToggleDelete: context
                        .read<GroupDetailCubit>()
                        .toggleDeleteMode,
                    onDeleteMember: (member) => _confirmRemove(context, member),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: flashCardDecoration(),
              child: Column(
                children: [
                  GroupNameEditor(
                    name: detail.name,
                    canEdit: detail.isOwner && !state.isSaving,
                    onSave: context.read<GroupDetailCubit>().updateName,
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    key: const Key('group-number-row'),
                    title: const Text('群号'),
                    subtitle: Text(
                      detail.conversationId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    key: const Key('group-announcement-row'),
                    title: const Text('群公告'),
                    subtitle: Text(
                      detail.announcement.isEmpty
                          ? '暂无群公告'
                          : detail.announcement,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: FlashPalette.secondaryInk),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: FlashPalette.mutedInk,
                    ),
                    onTap: state.isSaving
                        ? null
                        : () => _openAnnouncement(context, detail),
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    title: const Text('入群验证'),
                    subtitle: Text(
                      detail.joinApprovalRequired
                          ? '成员邀请和用户主动申请均需确认后加入'
                          : '成员邀请好友或用户主动申请时可直接加入',
                    ),
                    trailing: CupertinoSwitch(
                      key: const Key('group-join-approval-switch'),
                      value: detail.joinApprovalRequired,
                      activeTrackColor: FlashPalette.primary,
                      inactiveTrackColor: const Color(0xFFD5DCE7),
                      thumbColor: FlashPalette.surface,
                      inactiveThumbColor: FlashPalette.surface,
                      trackOutlineColor:
                          WidgetStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.transparent;
                            }
                            return states.contains(WidgetState.disabled)
                                ? const Color(0xFFB6C0CF)
                                : const Color(0xFFAAB5C5);
                          }),
                      trackOutlineWidth: const WidgetStatePropertyAll<double?>(
                        1,
                      ),
                      onChanged: detail.isOwner && !state.isSaving
                          ? context.read<GroupDetailCubit>().updateSettings
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: flashCardDecoration(),
              child: Column(
                children: [
                  if (detail.isOwner) ...[
                    ListTile(
                      key: const Key('group-transfer-owner-row'),
                      title: const Text('转让群主'),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: FlashPalette.mutedInk,
                      ),
                      onTap: state.isSaving
                          ? null
                          : () => _openTransferOwner(context, detail),
                    ),
                    const Divider(height: 1, indent: 16),
                  ],
                  ListTile(
                    key: Key(
                      detail.isOwner
                          ? 'group-dissolve-button'
                          : 'group-leave-button',
                    ),
                    title: Text(
                      detail.isOwner ? '解散群聊' : '退出群聊',
                      style: const TextStyle(color: FlashPalette.danger),
                    ),
                    onTap: state.isSaving
                        ? null
                        : detail.isOwner
                        ? () => _confirmDissolve(context)
                        : () => _confirmLeave(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (state.isSaving)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x22000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Future<void> _pickMembers(BuildContext context, GroupDetail detail) async {
    final selected = await Navigator.of(context).push<List<FriendUser>>(
      MaterialPageRoute(
        builder: (_) => GroupMemberPickerPage(
          existingMemberIds: detail.members
              .map((member) => member.accountId)
              .toSet(),
        ),
      ),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;
    final ids = selected
        .map((friend) => friend.accountId)
        .toList(growable: false);
    final cubit = context.read<GroupDetailCubit>();
    if (detail.isOwner || !detail.joinApprovalRequired) {
      await cubit.addMembers(ids);
      return;
    }
    final sent = await cubit.inviteMembers(ids);
    if (sent && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('群邀请卡片已发送')));
    }
  }

  Future<void> _confirmRemove(BuildContext context, GroupMember member) async {
    if (member.isOwner) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除群成员'),
        content: Text('确定将“${member.displayName}”移出群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('group-member-remove-confirm'),
            style: FilledButton.styleFrom(backgroundColor: FlashPalette.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<GroupDetailCubit>().removeMember(member.accountId);
    }
  }

  Future<void> _confirmDissolve(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('解散群聊'),
        content: const Text('解散后群聊将转为只读，原成员仍可查看历史消息，且此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('group-dissolve-confirm'),
            style: FilledButton.styleFrom(backgroundColor: FlashPalette.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认解散'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<GroupDetailCubit>().dissolveGroup();
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出群聊'),
        content: const Text('退出后将无法继续查看该群聊和历史消息，确定退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('group-leave-confirm'),
            style: FilledButton.styleFrom(backgroundColor: FlashPalette.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<GroupDetailCubit>().leaveGroup();
    }
  }

  Future<void> _openAnnouncement(
    BuildContext context,
    GroupDetail detail,
  ) async {
    final cubit = context.read<GroupDetailCubit>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GroupAnnouncementPage(
          announcement: detail.announcement,
          canEdit: detail.isOwner,
          updatedByName: detail.announcementUpdatedByName,
          updatedAt: detail.announcementUpdatedAt,
          onPublish: cubit.updateAnnouncement,
        ),
      ),
    );
  }

  Future<void> _openTransferOwner(
    BuildContext context,
    GroupDetail detail,
  ) async {
    final cubit = context.read<GroupDetailCubit>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TransferGroupOwnerPage(
          members: detail.members,
          onTransfer: cubit.transferOwner,
        ),
      ),
    );
  }

  void _popUpdated(BuildContext context, GroupDetail? detail) {
    if (detail == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(
      context,
    ).pop(GroupDetailsResult.updated(detail.applyToConversation(conversation)));
  }
}
