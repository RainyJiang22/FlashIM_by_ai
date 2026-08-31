import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../../data/group_discovery.dart';

class GroupSearchResultTile extends StatelessWidget {
  const GroupSearchResultTile({
    super.key,
    required this.item,
    required this.isActing,
    required this.onTap,
  });

  final GroupSearchItem item;
  final bool isActing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GroupAvatarWidget(
            avatar: item.avatar,
            seed: item.conversationId,
            size: 58,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlashPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.memberCount} 人 · 群号 ${item.groupNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlashPalette.secondaryInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _action(),
        ],
      ),
    );
  }

  Widget _action() {
    if (isActing) {
      return const SizedBox.square(
        dimension: 30,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (item.isMember || item.hasPendingRequest) {
      return Container(
        key: Key(
          item.isMember ? 'group-search-joined' : 'group-search-pending',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          item.isMember ? '已加入' : '已申请',
          style: const TextStyle(
            color: FlashPalette.mutedInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (item.joinApprovalRequired) {
      return OutlinedButton(
        key: const Key('group-search-apply'),
        style: OutlinedButton.styleFrom(
          foregroundColor: FlashPalette.warning,
          side: const BorderSide(color: FlashPalette.warning),
          minimumSize: const Size(70, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        onPressed: onTap,
        child: const Text('申请'),
      );
    }
    return FilledButton(
      key: const Key('group-search-join'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(70, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      onPressed: onTap,
      child: const Text('加入'),
    );
  }
}
