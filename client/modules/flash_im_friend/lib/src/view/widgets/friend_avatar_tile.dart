import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../../data/friend_user.dart';
import 'friend_ui.dart';

class FriendAvatarTile extends StatelessWidget {
  const FriendAvatarTile({
    super.key,
    required this.user,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isOnline = false,
  });

  final FriendUser user;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AvatarWidget(
                    avatar: user.avatar,
                    seed: '${user.accountId}',
                    size: 52,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  if (isOnline)
                    Positioned(
                      key: const Key('friend-online-indicator'),
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF07C160),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FriendPalette.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (subtitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FriendPalette.secondaryInk,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
