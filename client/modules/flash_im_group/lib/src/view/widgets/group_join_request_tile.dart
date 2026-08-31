import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../../data/group_discovery.dart';

class GroupJoinRequestTile extends StatelessWidget {
  const GroupJoinRequestTile({
    super.key,
    required this.request,
    required this.isHandling,
    required this.onApprove,
    required this.onReject,
  });

  final GroupJoinRequest request;
  final bool isHandling;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarWidget(
            avatar: request.applicantAvatar,
            seed: '${request.applicantId}',
            size: 54,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.applicantName,
                  style: const TextStyle(
                    color: FlashPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '申请加入 ${request.groupName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: FlashPalette.secondaryInk),
                ),
                if (request.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '留言：${request.message}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlashPalette.mutedInk,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _actions(),
        ],
      ),
    );
  }

  Widget _actions() {
    if (!request.isPending) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          request.status == GroupJoinRequestStatus.approved ? '已同意' : '已拒绝',
          style: const TextStyle(
            color: FlashPalette.mutedInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (isHandling) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          key: const Key('group-request-reject'),
          onPressed: onReject,
          child: const Text(
            '拒绝',
            style: TextStyle(color: FlashPalette.secondaryInk),
          ),
        ),
        const SizedBox(width: 4),
        FilledButton(
          key: const Key('group-request-approve'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onApprove,
          child: const Text('同意'),
        ),
      ],
    );
  }
}
