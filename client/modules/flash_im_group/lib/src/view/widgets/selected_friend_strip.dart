import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class SelectedFriendStrip extends StatelessWidget {
  const SelectedFriendStrip({
    super.key,
    required this.friends,
    required this.selectedIds,
    required this.lockedIds,
    required this.onRemove,
  });

  final List<FriendUser> friends;
  final Set<int> selectedIds;
  final Set<int> lockedIds;
  final ValueChanged<FriendUser> onRemove;

  @override
  Widget build(BuildContext context) {
    final selected = friends
        .where((friend) => selectedIds.contains(friend.accountId))
        .toList(growable: false);
    if (selected.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 78,
      child: ListView.separated(
        key: const Key('selected-friend-strip'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: selected.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final friend = selected[index];
          final isLocked = lockedIds.contains(friend.accountId);
          return Tooltip(
            message: isLocked
                ? '${friend.displayName}（固定成员）'
                : '取消选择 ${friend.displayName}',
            child: InkWell(
              key: ValueKey('selected-friend-avatar-${friend.accountId}'),
              onTap: isLocked ? null : () => onRemove(friend),
              borderRadius: BorderRadius.circular(15),
              child: AvatarWidget(
                avatar: friend.avatar,
                seed: friend.accountId.toString(),
                size: 52,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          );
        },
      ),
    );
  }
}
