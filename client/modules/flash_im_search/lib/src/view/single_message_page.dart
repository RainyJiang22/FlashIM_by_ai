import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import 'message_detail_page.dart';
import 'widgets/highlight_text.dart';

class SingleMessagePage extends StatelessWidget {
  const SingleMessagePage({
    super.key,
    required this.message,
    required this.keyword,
  });

  final Message message;
  final String keyword;

  @override
  Widget build(BuildContext context) {
    final senderName = message.senderName.trim().isEmpty
        ? '用户 ${message.senderId}'
        : message.senderName;
    return Scaffold(
      appBar: AppBar(title: const Text('消息详情')),
      backgroundColor: FlashPalette.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: flashCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarWidget(
                      avatar: message.senderAvatar,
                      seed: message.senderId,
                      size: 50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            formatSearchTime(message.createdAt),
                            style: const TextStyle(
                              color: FlashPalette.mutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                HighlightText(
                  key: const Key('single-message-content'),
                  text: message.content,
                  keyword: keyword,
                  style: const TextStyle(
                    color: FlashPalette.ink,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
