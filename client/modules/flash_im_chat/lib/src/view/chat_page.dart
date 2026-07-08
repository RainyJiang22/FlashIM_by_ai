import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/message.dart';
import '../data/message_repository.dart';
import '../logic/chat_cubit.dart';
import '../logic/chat_state.dart';
import 'chat_input.dart';
import 'message_bubble.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    required this.currentUserId,
    this.currentUserName,
    this.currentUserAvatar,
  });

  final Conversation conversation;
  final String currentUserId;
  final String? currentUserName;
  final String? currentUserAvatar;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatCubit(
        repository: context.read<MessageRepository>(),
        wsClient: context.read<WsClient>(),
        conversation: conversation,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
      )..loadMessages(),
      child: _ChatScaffold(
        conversation: conversation,
        currentUserId: currentUserId,
        currentUserAvatar: currentUserAvatar,
      ),
    );
  }
}

class _ChatScaffold extends StatelessWidget {
  const _ChatScaffold({
    required this.conversation,
    required this.currentUserId,
    this.currentUserAvatar,
  });

  final Conversation conversation;
  final String currentUserId;
  final String? currentUserAvatar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(conversation.displayName)),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: _MessageList(
                  currentUserId: currentUserId,
                  currentUserAvatar: currentUserAvatar,
                ),
              ),
              ChatInput(onSend: context.read<ChatCubit>().sendText),
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
      builder: (context, state) {
        return switch (state) {
          ChatInitial() || ChatLoading() => const _MessageSkeleton(),
          ChatError(:final message) => Center(child: Text(message)),
          ChatLoaded(:final messages) when messages.isEmpty => const Center(
            child: Text('还没有消息'),
          ),
          ChatLoaded(:final messages) => _LoadedMessageList(
            messages: messages,
            currentUserId: currentUserId,
            currentUserAvatar: currentUserAvatar,
          ),
        };
      },
    );
  }
}

class _LoadedMessageList extends StatelessWidget {
  const _LoadedMessageList({
    required this.messages,
    required this.currentUserId,
    this.currentUserAvatar,
  });

  final List<Message> messages;
  final String currentUserId;
  final String? currentUserAvatar;

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
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: reversed.length,
        itemBuilder: (context, index) {
          final message = reversed[index];
          return MessageBubble(
            message: message,
            isMine: message.senderId == currentUserId,
            currentUserAvatar: currentUserAvatar,
          );
        },
      ),
    );

    if (messages.length <= 15) {
      return Align(alignment: Alignment.topCenter, child: list);
    }
    return list;
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
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}
