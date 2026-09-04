import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../data/search_models.dart';
import 'widgets/highlight_text.dart';

class MessageDetailPage extends StatelessWidget {
  const MessageDetailPage({
    super.key,
    required this.group,
    required this.keyword,
    required this.onConversationTap,
  });

  final MessageSearchGroup group;
  final String keyword;
  final ValueChanged<Conversation> onConversationTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(group.conversation.displayName)),
      backgroundColor: FlashPalette.background,
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: group.messages.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
        itemBuilder: (context, index) => _MessageResultTile(
          message: group.messages[index],
          keyword: keyword,
          onTap: () => onConversationTap(group.conversation),
        ),
      ),
    );
  }
}

class MessageResultTile extends StatelessWidget {
  const MessageResultTile({
    super.key,
    required this.message,
    required this.keyword,
    required this.onTap,
  });

  final Message message;
  final String keyword;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      _MessageResultTile(message: message, keyword: keyword, onTap: onTap);
}

class _MessageResultTile extends StatelessWidget {
  const _MessageResultTile({
    required this.message,
    required this.keyword,
    required this.onTap,
  });

  final Message message;
  final String keyword;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('message-search-result-${message.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: AvatarWidget(
        avatar: message.senderAvatar,
        seed: message.senderId,
        size: 46,
        borderRadius: BorderRadius.circular(13),
      ),
      title: Text(
        message.senderName.trim().isEmpty
            ? '用户 ${message.senderId}'
            : message.senderName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: HighlightText(
          text: message.content,
          keyword: keyword,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: FlashPalette.secondaryInk),
        ),
      ),
      trailing: Text(
        formatSearchTime(message.createdAt),
        style: const TextStyle(color: FlashPalette.mutedInk, fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}

String formatSearchTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.month}/${local.day} ${two(local.hour)}:${two(local.minute)}';
}
