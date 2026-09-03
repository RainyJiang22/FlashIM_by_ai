import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../../data/message.dart';
import '../../logic/chat_state.dart';
import 'file_bubble.dart';
import 'group_invitation_bubble.dart';
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
    this.onAcceptGroupInvitation,
    this.isGroupChat = false,
    this.groupMemberCount = 0,
    this.onReadStatusTap,
  });

  final Message message;
  final bool isMine;
  final String? currentUserAvatar;
  final VoidCallback? onOpenImage;
  final VoidCallback? onOpenVideo;
  final VoidCallback? onOpenFile;
  final FileDownloadInfo? downloadInfo;
  final double? uploadProgress;
  final Future<void> Function(String invitationId)? onAcceptGroupInvitation;
  final bool isGroupChat;
  final int groupMemberCount;
  final VoidCallback? onReadStatusTap;

  @override
  Widget build(BuildContext context) {
    if (message.isGroupCreated) {
      final displayText = _groupSystemMessageText(message);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Align(
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECF1),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              displayText,
              key: const Key('group-created-message'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FlashPalette.mutedInk,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ),
      );
    }

    final avatar = AvatarWidget(
      avatar: isMine
          ? (currentUserAvatar ?? message.senderAvatar)
          : message.senderAvatar,
      seed: message.senderId,
      size: 40,
      borderRadius: BorderRadius.circular(14),
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
      MessageType.groupInvitation => GroupInvitationBubble(
        message: message,
        canAccept: !isMine,
        onAccept: onAcceptGroupInvitation,
      ),
      MessageType.groupCreated => const SizedBox.shrink(),
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
                      color: FlashPalette.secondaryInk,
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
                    if (isMine)
                      _MessageStatusIcon(
                        status: message.status,
                        showReadStatus: !isGroupChat,
                        isRead: message.readCount > 0,
                        groupReadCount: isGroupChat ? message.readCount : null,
                        groupMemberCount: groupMemberCount,
                        onGroupReadStatusTap: onReadStatusTap,
                      ),
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

String _groupSystemMessageText(Message message) {
  final content = message.content.trim();
  final senderName = message.senderName.trim();
  final event = message.extra?['system_event'];

  if (event == 'group_created' ||
      (event == null && _isLegacyProtocolPayload(content))) {
    return senderName.isEmpty ? '创建了群聊' : '$senderName 创建了群聊';
  }
  if (content.isNotEmpty && !_isLegacyProtocolPayload(content)) {
    return content;
  }
  final actor = senderName.isEmpty ? '有成员' : senderName;
  return switch (event) {
    'member_joined' => '$actor 加入了群聊',
    'member_invited' => '$actor 邀请新成员进群',
    'announcement_updated' => '$actor 更新了群公告',
    'group_name_updated' => '$actor 修改了群名',
    'owner_transferred' => '$actor 转让了群主',
    'member_left' => '$actor 退出了群聊',
    'member_removed' => '$actor 移出了一名群成员',
    'group_dissolved' => '群聊已解散',
    _ => '群聊信息已更新',
  };
}

bool _isLegacyProtocolPayload(String content) {
  final normalized = content.toLowerCase();
  return normalized.startsWith('http://') ||
      normalized.startsWith('https://') ||
      normalized.startsWith('grid:') ||
      normalized.startsWith('identicon:');
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({
    required this.status,
    required this.showReadStatus,
    required this.isRead,
    required this.groupReadCount,
    required this.groupMemberCount,
    required this.onGroupReadStatusTap,
  });

  final MessageStatus status;
  final bool showReadStatus;
  final bool isRead;
  final int? groupReadCount;
  final int groupMemberCount;
  final VoidCallback? onGroupReadStatusTap;

  @override
  Widget build(BuildContext context) => switch (status) {
    MessageStatus.sending => const SizedBox.square(
      dimension: 12,
      child: CircularProgressIndicator(strokeWidth: 1.6),
    ),
    MessageStatus.failed => const Icon(
      Icons.error_outline,
      color: FlashPalette.danger,
      size: 14,
    ),
    MessageStatus.sent =>
      groupReadCount != null
          ? _GroupReadProgressIndicator(
              readCount: groupReadCount!,
              memberCount: groupMemberCount,
              onTap: onGroupReadStatusTap,
            )
          : showReadStatus
          ? Semantics(
              label: isRead ? '已读' : '未读',
              child: Container(
                key: Key(
                  isRead
                      ? 'private-message-read-indicator'
                      : 'private-message-unread-indicator',
                ),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRead ? FlashPalette.primary : Colors.transparent,
                  border: Border.all(
                    color: isRead
                        ? FlashPalette.primary
                        : FlashPalette.mutedInk,
                    width: 1.4,
                  ),
                ),
                child: isRead
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
            )
          : const SizedBox.shrink(),
  };
}

class _GroupReadProgressIndicator extends StatelessWidget {
  const _GroupReadProgressIndicator({
    required this.readCount,
    required this.memberCount,
    this.onTap,
  });

  final int readCount;
  final int memberCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final recipientCount = memberCount > 0 ? memberCount - 1 : 0;
    final unreadCount = recipientCount > readCount
        ? recipientCount - readCount
        : 0;
    final hasMemberCount = memberCount > 0;
    final isAllRead = hasMemberCount && unreadCount == 0;
    final progress = recipientCount == 0
        ? (hasMemberCount ? 1.0 : 0.0)
        : (readCount / recipientCount).clamp(0.0, 1.0);

    return Semantics(
      label: !hasMemberCount
          ? '群聊已读进度未知'
          : isAllRead
          ? '全部已读'
          : '$unreadCount 人未读',
      button: onTap != null,
      child: GestureDetector(
        key: const Key('message-read-status'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(
            key: const Key('group-message-read-progress'),
            value: progress,
            strokeWidth: 1.6,
            backgroundColor: const Color(0xFFD8DDE7),
            color: FlashPalette.primary,
          ),
        ),
      ),
    );
  }
}
