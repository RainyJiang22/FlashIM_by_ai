import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_request.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';
import 'widgets/friend_avatar_tile.dart';

class NewFriendsPage extends StatelessWidget {
  const NewFriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新的朋友')),
      body: BlocBuilder<FriendCubit, FriendState>(
        builder: (context, state) {
          final requests = state.requestHistory;
          if (requests.isEmpty) {
            return RefreshIndicator(
              onRefresh: context.read<FriendCubit>().refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(
                    child: Text(
                      '暂无新的朋友',
                      style: TextStyle(color: Color(0xFF8A8A8A)),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: context.read<FriendCubit>().refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
              itemBuilder: (context, index) {
                final request = requests[index];
                return _RequestTile(
                  request: request,
                  processing: state.processingRequestIds.contains(request.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.processing});

  final FriendRequest request;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    return FriendAvatarTile(
      user: request.otherUser,
      subtitle: _requestSubtitle(request),
      trailing: processing
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : _requestTrailing(context),
    );
  }

  Widget _requestTrailing(BuildContext context) {
    if (request.isReceived && request.isPending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _confirmReject(context),
            child: const Text('拒绝'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(58, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => context.read<FriendCubit>().acceptRequest(request),
            child: const Text('接受'),
          ),
        ],
      );
    }
    final label = switch (request.status) {
      'accepted' => '已添加',
      'rejected' => '已拒绝',
      _ => '等待验证',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 14),
      ),
    );
  }

  String _requestSubtitle(FriendRequest request) {
    var message = request.message.trim().isEmpty
        ? '请求添加你为好友'
        : request.message.trim();
    if (!request.isReceived) {
      message = request.message.trim().isEmpty
          ? '你发送了朋友验证'
          : '你发送：${request.message.trim()}';
    }
    final difference = DateTime.now().difference(request.createdAt.toLocal());
    final timeLabel = switch (difference) {
      Duration(inDays: final days) when days > 0 => '$days天前',
      Duration(inHours: final hours) when hours > 0 => '$hours小时前',
      Duration(inMinutes: final minutes) when minutes > 0 => '$minutes分钟前',
      _ => '刚刚',
    };
    return '$message · $timeLabel';
  }

  Future<void> _confirmReject(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('拒绝好友申请？'),
        content: Text('将拒绝 ${request.otherUser.displayName} 的好友申请。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('拒绝'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<FriendCubit>().rejectRequest(request);
    }
  }
}
