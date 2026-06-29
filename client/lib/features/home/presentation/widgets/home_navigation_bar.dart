import 'package:flutter/material.dart';

class HomeNavigationBar extends StatelessWidget {
  const HomeNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onDestinationSelected,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 0,
      selectedItemColor: const Color(0xFF07C160),
      unselectedItemColor: const Color(0xFF111111),
      selectedFontSize: 13,
      unselectedFontSize: 13,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline, size: 30),
          activeIcon: Icon(Icons.chat_bubble, size: 30),
          label: '消息',
        ),
        BottomNavigationBarItem(
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
    );
  }
}
