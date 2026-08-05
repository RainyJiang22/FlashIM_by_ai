import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class HomeNavigationBar extends StatelessWidget {
  const HomeNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.messageUnreadCount = 0,
    this.contactRequestCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final int messageUnreadCount;
  final int contactRequestCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FlashPalette.surface,
        border: Border(top: BorderSide(color: FlashPalette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onDestinationSelected,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: FlashPalette.primary,
        unselectedItemColor: FlashPalette.secondaryInk,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        iconSize: 25,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: [
          BottomNavigationBarItem(
            icon: _messageIcon(Icons.chat_bubble_outline),
            activeIcon: _messageIcon(Icons.chat_bubble),
            label: '消息',
          ),
          BottomNavigationBarItem(
            icon: _contactIcon(Icons.people_outline),
            activeIcon: _contactIcon(Icons.people),
            label: '通讯录',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }

  Widget _messageIcon(IconData icon) {
    if (messageUnreadCount <= 0) {
      return Icon(icon, size: 30);
    }
    return Badge(
      label: Text(messageUnreadCount > 99 ? '99+' : '$messageUnreadCount'),
      child: Icon(icon, size: 30),
    );
  }

  Widget _contactIcon(IconData icon) {
    if (contactRequestCount <= 0) {
      return Icon(icon, size: 30);
    }
    return Badge(
      label: Text(contactRequestCount > 99 ? '99+' : '$contactRequestCount'),
      child: Icon(icon, size: 30),
    );
  }
}
