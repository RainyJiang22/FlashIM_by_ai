import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/message.dart';
import '../data/message_repository.dart';
import '../data/video_thumbnail_service.dart';
import '../logic/chat_cubit.dart';
import '../logic/chat_state.dart';
import 'bubble/message_bubble.dart';
import 'chat_input.dart';
import 'file_preview_page.dart';
import 'image_preview_page.dart';
import 'video_player_page.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    required this.currentUserId,
    this.currentUserName,
    this.currentUserAvatar,
    this.videoThumbnailService,
    this.onDetailsTap,
  });

  final Conversation conversation;
  final String currentUserId;
  final String? currentUserName;
  final String? currentUserAvatar;
  final VideoThumbnailService? videoThumbnailService;
  final Future<void> Function()? onDetailsTap;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<MessageRepository>();
    final resolver = repository is DioMessageRepository
        ? repository.resolveMediaUrl
        : (String value) => value;
    return BlocProvider(
      create: (context) => ChatCubit(
        repository: repository,
        wsClient: context.read<WsClient>(),
        conversation: conversation,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
        videoThumbnailService:
            videoThumbnailService ?? NativeVideoThumbnailService(),
        mediaUrlResolver: resolver,
      )..loadMessages(),
      child: _ChatScaffold(
        conversation: conversation,
        currentUserId: currentUserId,
        currentUserAvatar: currentUserAvatar,
        onDetailsTap: onDetailsTap,
      ),
    );
  }
}

class _ChatScaffold extends StatelessWidget {
  const _ChatScaffold({
    required this.conversation,
    required this.currentUserId,
    this.currentUserAvatar,
    this.onDetailsTap,
  });

  final Conversation conversation;
  final String currentUserId;
  final String? currentUserAvatar;
  final Future<void> Function()? onDetailsTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(conversation.displayName),
        actions: [
          if (conversation.isPrivateChat && onDetailsTap != null)
            IconButton(
              key: const Key('chat-details-action'),
              tooltip: '聊天详情',
              onPressed: onDetailsTap,
              icon: const Icon(Icons.more_horiz_rounded),
            ),
        ],
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: ColoredBox(
          color: FlashPalette.background,
          child: Column(
            children: [
              Expanded(
                child: _MessageList(
                  currentUserId: currentUserId,
                  currentUserAvatar: currentUserAvatar,
                ),
              ),
              ChatInput(
                onSend: context.read<ChatCubit>().sendText,
                onSendImage: context.read<ChatCubit>().sendImageFromFile,
                onSendVideo: context.read<ChatCubit>().sendVideoFromFile,
                onSendFile: context.read<ChatCubit>().sendFileFromPicker,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.currentUserId, this.currentUserAvatar});
  final String currentUserId;
  final String? currentUserAvatar;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) => switch (state) {
        ChatInitial() || ChatLoading() => const _MessageSkeleton(),
        ChatError(:final message) => _ChatMessageError(message: message),
        ChatLoaded(:final messages) when messages.isEmpty => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, color: FlashPalette.primary, size: 38),
              SizedBox(height: 14),
              Text(
                '还没有消息',
                style: TextStyle(
                  color: FlashPalette.secondaryInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ChatLoaded(
          :final messages,
          :final fileDownloads,
          :final uploadProgress,
        ) =>
          _LoadedMessageList(
            messages: messages,
            currentUserId: currentUserId,
            currentUserAvatar: currentUserAvatar,
            fileDownloads: fileDownloads,
            uploadProgress: uploadProgress,
          ),
      },
    );
  }
}

class _LoadedMessageList extends StatelessWidget {
  const _LoadedMessageList({
    required this.messages,
    required this.currentUserId,
    required this.fileDownloads,
    this.currentUserAvatar,
    this.uploadProgress,
  });

  final List<Message> messages;
  final String currentUserId;
  final String? currentUserAvatar;
  final Map<String, FileDownloadInfo> fileDownloads;
  final double? uploadProgress;

  @override
  Widget build(BuildContext context) {
    final reversed = messages.reversed.toList(growable: false);
    final list = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 180) {
          context.read<ChatCubit>().loadMore();
        }
        return false;
      },
      child: ListView.builder(
        reverse: true,
        shrinkWrap: messages.length <= 15,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        itemCount: reversed.length,
        itemBuilder: (context, index) {
          final message = reversed[index];
          return MessageBubble(
            message: message,
            isMine: message.senderId == currentUserId,
            currentUserAvatar: currentUserAvatar,
            downloadInfo: fileDownloads[message.id],
            uploadProgress: message.status == MessageStatus.sending
                ? uploadProgress
                : null,
            onOpenImage: () => _openImage(context, message),
            onOpenVideo: () => _openVideo(context, message),
            onOpenFile: () => _openFile(context, message),
          );
        },
      ),
    );
    return messages.length <= 15
        ? Align(alignment: Alignment.topCenter, child: list)
        : list;
  }

  void _openImage(BuildContext context, Message message) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImagePreviewPage(imageUrl: message.content),
      ),
    );
  }

  void _openVideo(BuildContext context, Message message) {
    final local = '${message.extra?['local_video_path'] ?? ''}';
    final remote = '${message.extra?['video_url'] ?? ''}';
    final source = local.isNotEmpty
        ? local
        : (remote.isNotEmpty ? remote : message.content);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerPage(videoUrl: source),
      ),
    );
  }

  void _openFile(BuildContext context, Message message) {
    final cubit = context.read<ChatCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: FilePreviewPage(message: message),
        ),
      ),
    );
  }
}

class _MessageSkeleton extends StatelessWidget {
  const _MessageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: 8,
      itemBuilder: (context, index) {
        final mine = index.isEven;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: mine ? 180 : 220,
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: FlashPalette.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

class _ChatMessageError extends StatelessWidget {
  const _ChatMessageError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: FlashPalette.mutedInk,
              size: 38,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FlashPalette.secondaryInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
