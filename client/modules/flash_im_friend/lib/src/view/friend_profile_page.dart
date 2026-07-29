import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';
import 'new_friends_page.dart';
import 'send_friend_request_page.dart';

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
          backgroundColor: const Color(0xFFEDEDED),
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: const SizedBox.shrink(),
            actions: current.isFriend
                ? [
                    PopupMenuButton<_ProfileMenuAction>(
                      tooltip: '更多',
                      icon: const Icon(Icons.more_horiz, size: 30),
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
                            style: TextStyle(color: Color(0xFFE35D6A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ]
                : null,
          ),
          body: ListView(
            children: [
              _ProfileHeader(user: current),
              const SizedBox(height: 10),
              _ProfileDetails(user: current),
              const SizedBox(height: 10),
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
        title: const Text('删除好友？'),
        content: Text('删除 ${current.displayName} 后，双方好友关系将解除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE35D6A),
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final FriendUser user;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarWidget(
              avatar: user.avatar,
              seed: '${user.accountId}',
              size: 88,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '闪讯号：${user.flashId ?? 'flash_${user.accountId}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    if (user.signature.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.signature.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 16,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.user});

  final FriendUser user;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          _DetailRow(label: '账号', value: '${user.accountId}'),
          const Divider(height: 1, indent: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF222222),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 16,
                height: 1.35,
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
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: processing ? null : () => _handle(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 74),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (processing)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Icon(
                  user.isFriend
                      ? Icons.chat_bubble_outline
                      : Icons.person_add_alt_1_outlined,
                  color: const Color(0xFF536F9F),
                  size: 29,
                ),
              const SizedBox(width: 12),
              Text(
                _label,
                style: TextStyle(
                  color: user.isPendingSent
                      ? const Color(0xFF999999)
                      : const Color(0xFF536F9F),
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _label {
    if (user.isFriend) {
      return '发消息';
    }
    if (user.isPendingSent) {
      return '等待验证';
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
    if (user.isPendingSent) {
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
