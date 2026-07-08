import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../data/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bubble = DecoratedBox(
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
          message.content,
          style: TextStyle(
            color: isMine ? Colors.white : const Color(0xFF111111),
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            AvatarWidget(
              avatar: message.senderAvatar,
              seed: message.senderId,
              size: 36,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMine && message.senderName.trim().isNotEmpty) ...[
                  Text(
                    message.senderName,
                    style: const TextStyle(
                      color: Color(0xFF7A7A7A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isMine) _MessageStatusIcon(status: message.status),
                    if (isMine) const SizedBox(width: 6),
                    Flexible(child: bubble),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MessageStatus.sending => const SizedBox.square(
        dimension: 12,
        child: CircularProgressIndicator(strokeWidth: 1.6),
      ),
      MessageStatus.failed => const Icon(
        Icons.error_outline,
        color: Color(0xFFE35D6A),
        size: 14,
      ),
      MessageStatus.sent => const SizedBox.shrink(),
    };
  }
}
