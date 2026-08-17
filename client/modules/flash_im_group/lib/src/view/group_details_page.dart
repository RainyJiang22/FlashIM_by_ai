import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/group_detail.dart';
import '../data/group_repository.dart';
import '../logic/group_detail_cubit.dart';
import '../logic/group_detail_state.dart';
import 'group_member_picker_page.dart';
import 'widgets/group_member_grid.dart';
import 'widgets/group_name_editor.dart';

class GroupDetailsPage extends StatelessWidget {
  const GroupDetailsPage({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GroupDetailCubit(
        repository: context.read<GroupRepository>(),
        groupId: conversation.id,
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
          previous.isDissolved != current.isDissolved,
      listener: (context, state) {
        if (state.isDissolved) {
          Navigator.of(context).pop(const GroupDetailsResult.dissolved());
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
                  SwitchListTile(
                    key: const Key('group-join-approval-switch'),
                    title: const Text('邀请确认'),
                    subtitle: Text(
                      detail.joinApprovalRequired
                          ? '群成员邀请好友时，对方同意后才能加入'
                          : '群成员可以直接添加自己的好友',
                    ),
                    value: detail.joinApprovalRequired,
                    onChanged: detail.isOwner && !state.isSaving
                        ? context.read<GroupDetailCubit>().updateSettings
                        : null,
                  ),
                ],
              ),
            ),
            if (detail.isOwner) ...[
              const SizedBox(height: 22),
              OutlinedButton(
                key: const Key('group-dissolve-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlashPalette.danger,
                  side: BorderSide(
                    color: FlashPalette.danger.withValues(alpha: 0.28),
                  ),
                  backgroundColor: FlashPalette.surface,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: state.isSaving
                    ? null
                    : () => _confirmDissolve(context),
                child: const Text('解散群聊'),
              ),
            ],
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
        content: const Text('解散后所有成员都将无法继续使用该群聊，且此操作不可撤销。'),
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
