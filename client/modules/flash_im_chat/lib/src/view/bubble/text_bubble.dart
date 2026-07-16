import 'package:flutter/material.dart';

class TextBubble extends StatelessWidget {
  const TextBubble({super.key, required this.content, required this.isMine});

  final String content;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('text_bubble'),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFF3B82F6) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(isMine ? 12 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Text(
          content,
          style: TextStyle(
            color: isMine ? Colors.white : const Color(0xFF111111),
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
