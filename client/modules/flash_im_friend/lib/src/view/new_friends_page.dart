import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_request.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';
import 'widgets/friend_avatar_tile.dart';
import 'widgets/friend_ui.dart';

class NewFriendsPage extends StatelessWidget {
  const NewFriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FriendPalette.background,
      appBar: AppBar(
        backgroundColor: FriendPalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: FriendPalette.ink,
        title: const Text('新的朋友'),
      ),
      body: BlocBuilder<FriendCubit, FriendState>(
        builder: (context, state) {
          final requests = state.requestHistory;
          if (requests.isEmpty) {
            return RefreshIndicator(
              color: FriendPalette.primary,
              backgroundColor: FriendPalette.surface,
              onRefresh: context.read<FriendCubit>().refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: const [
                  FriendCard(
                    child: FriendEmptyState(
                      icon: Icons.person_add_alt_1_rounded,
                      title: '暂无新的朋友',
                      message: '收到或发送好友申请后，会在这里留下记录',
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: FriendPalette.primary,
            backgroundColor: FriendPalette.surface,
            onRefresh: context.read<FriendCubit>().refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                FriendSectionTitle(
                  title: '申请记录',
                  caption: '${requests.length} 条记录 · 只保留待处理申请提醒',
                ),
                FriendCard(
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < requests.length;
                        index += 1
                      ) ...[
                        _RequestTile(
                          request: requests[index],
                          processing: state.processingRequestIds.contains(
                            requests[index].id,
                          ),
                        ),
                        if (index != requests.length - 1)
                          const Divider(
                            height: 1,
                            indent: 84,
                            endIndent: 16,
                            color: FriendPalette.border,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
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
              child: CircularProgressIndicator(
                color: FriendPalette.primary,
                strokeWidth: 2.2,
              ),
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
            style: TextButton.styleFrom(
              foregroundColor: FriendPalette.secondaryInk,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 38),
            ),
            child: const Text('拒绝'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FriendPalette.primary,
              minimumSize: const Size(58, 38),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => context.read<FriendCubit>().acceptRequest(request),
            child: const Text('接受'),
          ),
        ],
      );
    }

    final status = switch (request.status) {
      'accepted' => const FriendStatusPill(
        label: '已添加',
        color: FriendPalette.success,
        backgroundColor: FriendPalette.successSoft,
        icon: Icons.check_rounded,
      ),
      'rejected' => const FriendStatusPill(
        label: '已拒绝',
        color: FriendPalette.danger,
        backgroundColor: FriendPalette.dangerSoft,
        icon: Icons.close_rounded,
      ),
      _ => const FriendStatusPill(
        label: '等待验证',
        color: FriendPalette.secondaryInk,
        icon: Icons.schedule_rounded,
      ),
    };
    return status;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('拒绝好友申请？'),
        content: Text('将拒绝 ${request.otherUser.displayName} 的好友申请。'),
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
