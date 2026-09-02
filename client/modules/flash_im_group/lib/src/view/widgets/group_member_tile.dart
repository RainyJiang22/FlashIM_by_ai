import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../../data/group_detail.dart';

class GroupMemberTile extends StatelessWidget {
  const GroupMemberTile({
    super.key,
    required this.member,
    this.showDelete = false,
    this.onDelete,
  });

  final GroupMember member;
  final bool showDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('group-member-${member.accountId}'),
      borderRadius: BorderRadius.circular(16),
      onTap: showDelete ? onDelete : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AvatarWidget(
                  avatar: member.avatar,
                  seed: member.accountId.toString(),
                  size: 48,
                  borderRadius: BorderRadius.circular(15),
                ),
                if (member.isOwner)
                  const Positioned(
                    right: -4,
                    bottom: -3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: FlashPalette.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ),
                if (member.isAdmin)
                  const Positioned(
                    right: -4,
                    bottom: -3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF5B67D6),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ),
                if (showDelete && !member.isOwner)
                  const Positioned(
                    right: -5,
                    top: -5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: FlashPalette.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.remove_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlashPalette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupMemberActionTile extends StatelessWidget {
  const GroupMemberActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? FlashPalette.danger : FlashPalette.primary;
    return InkWell(
      key: Key('group-member-action-$label'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDanger
                    ? FlashPalette.danger.withValues(alpha: 0.08)
                    : FlashPalette.primarySoft,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
