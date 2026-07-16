import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../../data/message.dart';
import '../../logic/chat_state.dart';
import 'file_bubble.dart';
import 'image_bubble.dart';
import 'text_bubble.dart';
import 'video_bubble.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.currentUserAvatar,
    this.onOpenImage,
    this.onOpenVideo,
    this.onOpenFile,
    this.downloadInfo,
    this.uploadProgress,
  });

  final Message message;
  final bool isMine;
  final String? currentUserAvatar;
  final VoidCallback? onOpenImage;
  final VoidCallback? onOpenVideo;
  final VoidCallback? onOpenFile;
  final FileDownloadInfo? downloadInfo;
  final double? uploadProgress;

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarWidget(
      avatar: isMine
          ? (currentUserAvatar ?? message.senderAvatar)
          : message.senderAvatar,
      seed: message.senderId,
      size: 36,
      borderRadius: BorderRadius.circular(8),
    );
    final content = switch (message.type) {
      MessageType.text => TextBubble(content: message.content, isMine: isMine),
      MessageType.image => ImageBubble(
        message: message,
        onTap: onOpenImage,
        uploadProgress: uploadProgress,
      ),
      MessageType.video => VideoBubble(
        message: message,
        onTap: onOpenVideo,
        uploadProgress: uploadProgress,
      ),
      MessageType.file => FileBubble(
        message: message,
        onTap: onOpenFile,
        downloadInfo: downloadInfo,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[avatar, const SizedBox(width: 8)],
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
                    Flexible(child: content),
                  ],
                ),
              ],
            ),
          ),
          if (isMine) ...[const SizedBox(width: 8), avatar],
        ],
      ),
    );
  }
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({required this.status});
  final MessageStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
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
