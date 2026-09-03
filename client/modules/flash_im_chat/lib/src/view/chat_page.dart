import 'dart:async';

import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/message.dart';
import '../data/message_repository.dart';
import '../data/mention.dart';
import '../data/video_thumbnail_service.dart';
import '../logic/chat_cubit.dart';
import '../logic/chat_state.dart';
import 'bubble/message_bubble.dart';
import 'chat_input.dart';
import 'file_preview_page.dart';
import 'image_preview_page.dart';
import 'message_read_status_sheet.dart';
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
    this.onAcceptGroupInvitation,
    this.mentionDataLoader,
  });

  final Conversation conversation;
  final String currentUserId;
  final String? currentUserName;
  final String? currentUserAvatar;
  final VideoThumbnailService? videoThumbnailService;
  final Future<Conversation?> Function()? onDetailsTap;
  final Future<void> Function(String invitationId)? onAcceptGroupInvitation;
  final Future<ChatMentionPickerData> Function()? mentionDataLoader;

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
        onAcceptGroupInvitation: onAcceptGroupInvitation,
        mentionDataLoader: mentionDataLoader,
      ),
    );
  }
}

class _ChatScaffold extends StatefulWidget {
  const _ChatScaffold({
    required this.conversation,
    required this.currentUserId,
    this.currentUserAvatar,
    this.onDetailsTap,
    this.onAcceptGroupInvitation,
    this.mentionDataLoader,
  });

  final Conversation conversation;
  final String currentUserId;
  final String? currentUserAvatar;
  final Future<Conversation?> Function()? onDetailsTap;
  final Future<void> Function(String invitationId)? onAcceptGroupInvitation;
  final Future<ChatMentionPickerData> Function()? mentionDataLoader;

  @override
  State<_ChatScaffold> createState() => _ChatScaffoldState();
}

class _ChatScaffoldState extends State<_ChatScaffold> {
  late Conversation _displayConversation;
  StreamSubscription<GroupInfoUpdateNotification>? _groupInfoSubscription;
  var _isOpeningDetails = false;

  @override
  void initState() {
    super.initState();
    _displayConversation = widget.conversation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _groupInfoSubscription ??= context
        .read<WsClient>()
        .groupInfoUpdateStream
        .where((event) => event.conversationId == widget.conversation.id)
        .listen(_applyGroupInfoUpdate);
  }

  @override
  void dispose() {
    _groupInfoSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _ChatTitle(conversation: _displayConversation),
        actions: [
          if (widget.onDetailsTap != null && !_displayConversation.isDissolved)
            IconButton(
              key: const Key('chat-details-action'),
              tooltip: '聊天详情',
              onPressed: _openDetails,
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
              if (_displayConversation.isGroupChat &&
                  _displayConversation.announcement.trim().isNotEmpty)
                _AnnouncementBanner(
                  announcement: _displayConversation.announcement.trim(),
                  onTap:
                      widget.onDetailsTap != null &&
                          !_displayConversation.isDissolved
                      ? _openDetails
                      : null,
                ),
              Expanded(
                child: _MessageList(
                  currentUserId: widget.currentUserId,
                  currentUserAvatar: widget.currentUserAvatar,
                  isGroupChat: _displayConversation.isGroupChat,
                  groupMemberCount: _displayConversation.memberCount,
                  onAcceptGroupInvitation: widget.onAcceptGroupInvitation,
                ),
              ),
              if (_displayConversation.isDissolved)
                Container(
                  key: const Key('dissolved-chat-readonly'),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 18),
                  color: FlashPalette.surface,
                  child: const SafeArea(
                    top: false,
                    child: Text(
                      '该群聊已解散',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: FlashPalette.secondaryInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                ChatInput(
                  onSend: context.read<ChatCubit>().sendText,
                  onSendDraft: context.read<ChatCubit>().sendTextDraft,
                  mentionDataLoader: widget.mentionDataLoader,
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

  Future<void> _openDetails() async {
    if (_isOpeningDetails) return;
    _isOpeningDetails = true;
    try {
      final updated = await widget.onDetailsTap?.call();
      if (!mounted ||
          updated == null ||
          updated.id != _displayConversation.id) {
        return;
      }
      setState(() => _displayConversation = updated);
    } finally {
      _isOpeningDetails = false;
    }
  }

  void _applyGroupInfoUpdate(GroupInfoUpdateNotification update) {
    if (!mounted) return;
    if (!update.membershipActive) {
      // GroupDetailsPage receives the same WS event and must close its typed
      // route with GroupDetailsResult. Popping here would target that top route
      // with a bool and then race its own pop listener.
      if (_isOpeningDetails) return;
      final route = ModalRoute.of(context);
      if (route?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
      return;
    }
    setState(() {
      _displayConversation = _displayConversation.copyWith(
        type: 1,
        name: update.name,
        avatar: update.avatar,
        ownerId: update.ownerId.toString(),
        memberCount: update.memberCount,
        announcement: update.announcement,
        isDissolved: update.isDissolved,
      );
    });
  }
}

class _ChatTitle extends StatelessWidget {
  const _ChatTitle({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    if (!conversation.isPrivateChat) {
      return Text(conversation.displayName);
    }
    final peerId = int.tryParse(conversation.peerUserId ?? '');
    return ValueListenableBuilder<Set<int>>(
      valueListenable: context.read<WsClient>().onlineUserIds,
      builder: (context, onlineUserIds, _) {
        final isOnline = peerId != null && onlineUserIds.contains(peerId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(conversation.displayName),
            Text(
              textAlign: TextAlign.center,
              isOnline ? '在线' : '离线',
              key: const Key('chat-peer-presence'),
              style: TextStyle(
                color: isOnline
                    ? const Color(0xFF07C160)
                    : FlashPalette.mutedInk,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnnouncementBanner extends StatelessWidget {
  const _AnnouncementBanner({required this.announcement, this.onTap});

  final String announcement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('chat-announcement-banner'),
      color: const Color(0xFFFFF9E6),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF2E8BF), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.campaign_rounded,
                color: Color(0xFFE6A700),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  announcement,
                  key: const Key('chat-announcement-text'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlashPalette.secondaryInk,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: FlashPalette.mutedInk,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.currentUserId,
    required this.isGroupChat,
    required this.groupMemberCount,
    this.currentUserAvatar,
    this.onAcceptGroupInvitation,
  });
  final String currentUserId;
  final bool isGroupChat;
  final int groupMemberCount;
  final String? currentUserAvatar;
  final Future<void> Function(String invitationId)? onAcceptGroupInvitation;

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
            isGroupChat: isGroupChat,
            groupMemberCount: groupMemberCount,
            fileDownloads: fileDownloads,
            uploadProgress: uploadProgress,
            onAcceptGroupInvitation: onAcceptGroupInvitation,
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
    required this.isGroupChat,
    required this.groupMemberCount,
    this.currentUserAvatar,
    this.uploadProgress,
    this.onAcceptGroupInvitation,
  });

  final List<Message> messages;
  final String currentUserId;
  final String? currentUserAvatar;
  final Map<String, FileDownloadInfo> fileDownloads;
  final bool isGroupChat;
  final int groupMemberCount;
  final double? uploadProgress;
  final Future<void> Function(String invitationId)? onAcceptGroupInvitation;

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
            onAcceptGroupInvitation: onAcceptGroupInvitation,
            isGroupChat: isGroupChat,
            groupMemberCount: groupMemberCount,
            onReadStatusTap:
                isGroupChat &&
                    message.seq > 0 &&
                    message.senderId == currentUserId
                ? () => showMessageReadStatusSheet(
                    context: context,
                    repository: context.read<MessageRepository>(),
                    message: message,
                  )
                : null,
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
