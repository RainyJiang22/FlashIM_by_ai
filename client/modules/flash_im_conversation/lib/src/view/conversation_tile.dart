import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../data/conversation.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    this.isOnline = false,
    this.onTap,
  });

  final Conversation conversation;
  final bool isOnline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: flashCardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _ConversationAvatar(
                    conversation: conversation,
                    isOnline: isOnline,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversation.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: FlashPalette.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (conversation.isGroupChat &&
                                conversation.isDissolved) ...[
                              const SizedBox(width: 8),
                              Container(
                                key: const Key('dissolved-group-badge'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: FlashPalette.mutedInk.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '已解散',
                                  style: TextStyle(
                                    color: FlashPalette.secondaryInk,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          conversation.displayPreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: FlashPalette.secondaryInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatConversationTime(conversation.displayTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: FlashPalette.mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (conversation.unreadCount > 0) ...[
                        const SizedBox(height: 8),
                        _UnreadBadge(count: conversation.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    required this.conversation,
    required this.isOnline,
  });

  final Conversation conversation;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    if (conversation.isGroupChat) {
      return GroupAvatarWidget(
        avatar: conversation.groupAvatar,
        seed: conversation.id,
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AvatarWidget(
          avatar: conversation.peerAvatar?.trim(),
          seed: conversation.avatarSeed,
          size: 52,
          borderRadius: BorderRadius.circular(15),
        ),
        if (isOnline)
          Positioned(
            key: const Key('conversation-online-indicator'),
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
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFE35D6A),
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
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
