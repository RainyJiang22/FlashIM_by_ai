import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class SelectableFriendTile extends StatelessWidget {
  const SelectableFriendTile({
    super.key,
    required this.friend,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  final FriendUser friend;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('select-friend-${friend.accountId}'),
      onTap: isLocked ? null : onTap,
      leading: AvatarWidget(
        avatar: friend.avatar,
        seed: friend.accountId.toString(),
        size: 44,
        borderRadius: BorderRadius.circular(13),
      ),
      title: Text(
        friend.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: isLocked ? const Text('已包含在当前单聊中') : null,
      trailing: Icon(
        isLocked
            ? Icons.lock_rounded
            : isSelected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: isSelected || isLocked
            ? FlashPalette.primary
            : FlashPalette.mutedInk,
      ),
    );
  }
}
