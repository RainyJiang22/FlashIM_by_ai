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
          return SizedBox(
            width: 60,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Tooltip(
                    message: isLocked
                        ? '${friend.displayName}（固定成员）'
                        : friend.displayName,
                    child: AvatarWidget(
                      key: ValueKey(
                        'selected-friend-avatar-${friend.accountId}',
                      ),
                      avatar: friend.avatar,
                      seed: friend.accountId.toString(),
                      size: 52,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                if (!isLocked)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Tooltip(
                      message: '取消选择 ${friend.displayName}',
                      child: Semantics(
                        button: true,
                        label: '取消选择 ${friend.displayName}',
                        child: GestureDetector(
                          key: ValueKey(
                            'selected-friend-remove-${friend.accountId}',
                          ),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onRemove(friend),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFB8BDC5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
