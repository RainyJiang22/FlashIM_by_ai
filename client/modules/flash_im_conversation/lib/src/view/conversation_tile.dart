import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';

import '../data/conversation.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.conversation, this.onTap});

  final Conversation conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              _ConversationAvatar(conversation: conversation),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF111111),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      conversation.displayPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7A7A7A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatConversationTime(conversation.displayTime),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9AA6B2),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final avatar = conversation.peerAvatar;
    if (avatar != null && avatar.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          avatar,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => IdenticonAvatar(
            seed: conversation.avatarSeed,
            size: 48,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    return IdenticonAvatar(
      seed: conversation.avatarSeed,
      size: 48,
      borderRadius: BorderRadius.circular(8),
    );
  }
}

String _formatConversationTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }
  return '${_twoDigits(local.month)}/${_twoDigits(local.day)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
