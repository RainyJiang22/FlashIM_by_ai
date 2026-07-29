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
          appBar: AppBar(title: const Text('详细资料')),
          body: ListView(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AvatarWidget(
                      avatar: current.avatar,
                      seed: '${current.accountId}',
                      size: 72,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.displayName,
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '闪讯号：${current.flashId ?? 'flash_${current.accountId}'}',
                            style: const TextStyle(color: Color(0xFF7A7A7A)),
                          ),
                          if (current.signature.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              current.signature,
                              style: const TextStyle(color: Color(0xFF7A7A7A)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _PrimaryAction(
                  user: current,
                  processing: processing,
                  onMessageFriend: onMessageFriend,
                ),
              ),
              if (current.isFriend) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: const Color(0xFFE35D6A),
                    ),
                    onPressed: processing
                        ? null
                        : () => _deleteFriend(context, current),
                    child: const Text('删除好友'),
                  ),
                ),
              ],
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

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.user,
    required this.processing,
    required this.onMessageFriend,
  });

  final FriendUser user;
  final bool processing;
  final ValueChanged<FriendUser> onMessageFriend;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      onPressed: processing ? null : () => _handle(context),
      icon: processing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(user.isFriend ? Icons.chat_bubble_outline : Icons.person_add),
      label: Text(_label),
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
