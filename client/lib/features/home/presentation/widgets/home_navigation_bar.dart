import 'package:flutter/material.dart';

class HomeNavigationBar extends StatelessWidget {
  const HomeNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.messageUnreadCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final int messageUnreadCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE7EEF7), width: 0.8)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onDestinationSelected,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: const Color(0xFF1C4EFF),
        unselectedItemColor: const Color(0xFF6A7B92),
        selectedFontSize: 13,
        unselectedFontSize: 13,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        items: [
          BottomNavigationBarItem(
            icon: _messageIcon(Icons.chat_bubble_outline),
            activeIcon: _messageIcon(Icons.chat_bubble),
            label: '消息',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline, size: 30),
            activeIcon: Icon(Icons.people, size: 30),
            label: '通讯录',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 30),
            activeIcon: Icon(Icons.person, size: 30),
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
}
