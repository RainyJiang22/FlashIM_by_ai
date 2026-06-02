import 'package:flutter/material.dart';

class ConversationBottomNavigationBar extends StatelessWidget {
  const ConversationBottomNavigationBar({super.key, required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              Expanded(
                child: _BottomBarItem(
                  icon: Icons.chat_bubble,
                  label: '微信',
                  isSelected: true,
                  badgeCount: unreadCount,
                ),
              ),
              const Expanded(
                child: _BottomBarItem(
                  icon: Icons.perm_contact_calendar_outlined,
                  label: '通讯录',
                ),
              ),
              const Expanded(
                child: _BottomBarItem(
                  icon: Icons.explore_outlined,
                  label: '发现',
                  dotVisible: true,
                ),
              ),
              const Expanded(
                child: _BottomBarItem(icon: Icons.person_outline, label: '我'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.badgeCount = 0,
    this.dotVisible = false,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final bool dotVisible;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected
        ? const Color(0xFF07C160)
        : const Color(0xFF181818);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 31, color: foregroundColor),
            if (badgeCount > 0)
              Positioned(
                right: -18,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFA5151),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (dotVisible)
              const Positioned(
                right: -3,
                top: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFFA5151),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 11, height: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
