import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';
import 'new_friends_page.dart';
import 'send_friend_request_page.dart';
import 'widgets/friend_ui.dart';

class FriendProfilePage extends StatelessWidget {
  const FriendProfilePage({
    super.key,
    required this.user,
    required this.onMessageFriend,
  });

  final FriendUser user;
  final ValueChanged<FriendUser> onMessageFriend;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FriendCubit, FriendState>(
      builder: (context, state) {
        final current = _currentUser(state, user);
        final processing = state.processingUserIds.contains(current.accountId);
        return Scaffold(
          backgroundColor: FriendPalette.background,
          appBar: AppBar(
            backgroundColor: FriendPalette.background,
            surfaceTintColor: Colors.transparent,
            foregroundColor: FriendPalette.ink,
            title: const Text('个人资料'),
            actions: current.isFriend
                ? [
                    PopupMenuButton<_ProfileMenuAction>(
                      tooltip: '更多',
                      icon: const Icon(Icons.more_horiz_rounded, size: 27),
                      onSelected: (action) {
                        if (action == _ProfileMenuAction.deleteFriend) {
                          _deleteFriend(context, current);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<_ProfileMenuAction>(
                          value: _ProfileMenuAction.deleteFriend,
                          child: Text(
                            '删除好友',
                            style: TextStyle(color: FriendPalette.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ]
                : null,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ProfileHero(user: current),
              const SizedBox(height: 24),
              const FriendSectionTitle(title: '资料'),
              _ProfileDetails(user: current),
              const SizedBox(height: 20),
              _ProfileActionSection(
                user: current,
                processing: processing,
                onMessageFriend: onMessageFriend,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteFriend(BuildContext context, FriendUser current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('删除好友？'),
        content: Text('删除 ${current.displayName} 后，双方好友关系将解除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FriendPalette.danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final removed = await context.read<FriendCubit>().removeFriend(current);
    if (removed && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

enum _ProfileMenuAction { deleteFriend }

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final FriendUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF1FF), Color(0xFFF7FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE8FC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: FriendPalette.primary,
              shape: BoxShape.circle,
            ),
            child: AvatarWidget(
              avatar: user.avatar,
              seed: '${user.accountId}',
              size: 78,
              borderRadius: BorderRadius.all(Radius.circular(50)),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FriendPalette.ink,
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '闪讯号：${user.flashId ?? 'flash_${user.accountId}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FriendPalette.secondaryInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user.signature.trim().isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      user.signature.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FriendPalette.secondaryInk,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ProfileRelationTag(user: user),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRelationTag extends StatelessWidget {
  const _ProfileRelationTag({required this.user});

  final FriendUser user;

  @override
  Widget build(BuildContext context) {
    if (user.isFriend) {
      return const FriendStatusPill(
        label: '好友',
        color: FriendPalette.success,
        backgroundColor: FriendPalette.successSoft,
        icon: Icons.check_rounded,
      );
    }
    if (user.isPendingSent) {
      return const FriendStatusPill(
        label: '等待验证',
        color: FriendPalette.secondaryInk,
        icon: Icons.schedule_rounded,
      );
    }
    if (user.isPendingReceived) {
      return const FriendStatusPill(
        label: '待处理申请',
        color: FriendPalette.warning,
        backgroundColor: FriendPalette.warningSoft,
        icon: Icons.notifications_none_rounded,
      );
    }
    return const FriendStatusPill(
      label: '新朋友',
      color: FriendPalette.primary,
      backgroundColor: FriendPalette.primarySoft,
      icon: Icons.person_add_alt_1_rounded,
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.user});

  final FriendUser user;

  @override
  Widget build(BuildContext context) {
    return FriendCard(
      child: Column(
        children: [
          _DetailRow(label: '账号', value: '${user.accountId}'),
          const Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: FriendPalette.border,
          ),
          _DetailRow(
            label: '个性签名',
            value: user.signature.trim().isEmpty ? '暂无' : user.signature.trim(),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: FriendPalette.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: FriendPalette.secondaryInk,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionSection extends StatelessWidget {
  const _ProfileActionSection({
    required this.user,
    required this.processing,
    required this.onMessageFriend,
  });

  final FriendUser user;
  final bool processing;
  final ValueChanged<FriendUser> onMessageFriend;

  @override
  Widget build(BuildContext context) {
    if (processing) {
      return const SizedBox(
        height: 54,
        child: Center(
          child: CircularProgressIndicator(
            color: FriendPalette.primary,
            strokeWidth: 2.2,
          ),
        ),
      );
    }

    if (user.isPendingSent) {
      return SizedBox(
        height: 54,
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.schedule_rounded, size: 20),
          label: const Text('等待验证'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    final isFriend = user.isFriend;
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _handle(context),
        icon: Icon(
          isFriend
              ? Icons.chat_bubble_outline_rounded
              : Icons.person_add_alt_1_rounded,
          size: 20,
        ),
        label: Text(_label),
        style: FilledButton.styleFrom(
          backgroundColor: FriendPalette.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String get _label {
    if (user.isFriend) {
      return '发消息';
    }
    if (user.isPendingReceived) {
      return '处理好友申请';
    }
    return '添加到通讯录';
  }

  void _handle(BuildContext context) {
    if (user.isFriend) {
      onMessageFriend(user);
      return;
    }
    final cubit = context.read<FriendCubit>();
    if (user.isPendingReceived) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider<FriendCubit>.value(
            value: cubit,
            child: const NewFriendsPage(),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<FriendCubit>.value(
          value: cubit,
          child: SendFriendRequestPage(user: user),
        ),
      ),
    );
  }
}

FriendUser _currentUser(FriendState state, FriendUser fallback) {
  for (final friend in state.friends) {
    if (friend.accountId == fallback.accountId) {
      return friend.copyWith(relationStatus: 'friend');
    }
  }
  for (final result in state.searchResults) {
    if (result.accountId == fallback.accountId) {
      return result;
    }
  }
  return fallback;
}
