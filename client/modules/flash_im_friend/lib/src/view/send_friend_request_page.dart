import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';
import 'widgets/friend_ui.dart';

class SendFriendRequestPage extends StatefulWidget {
  const SendFriendRequestPage({super.key, required this.user});

  final FriendUser user;

  @override
  State<SendFriendRequestPage> createState() => _SendFriendRequestPageState();
}

class _SendFriendRequestPageState extends State<SendFriendRequestPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sent = await context.read<FriendCubit>().sendRequest(
      widget.user,
      _controller.text,
    );
    if (sent && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FriendPalette.background,
      appBar: AppBar(
        backgroundColor: FriendPalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: FriendPalette.ink,
        title: const Text('朋友验证'),
        actions: [
          BlocBuilder<FriendCubit, FriendState>(
            buildWhen: (previous, current) =>
                previous.processingUserIds != current.processingUserIds,
            builder: (context, state) {
              final processing = state.processingUserIds.contains(
                widget.user.accountId,
              );
              return TextButton(
                onPressed: processing ? null : _send,
                style: TextButton.styleFrom(
                  foregroundColor: FriendPalette.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: processing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          color: FriendPalette.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('发送'),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          FriendCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                AvatarWidget(
                  avatar: widget.user.avatar,
                  seed: '${widget.user.accountId}',
                  size: 58,
                  borderRadius: BorderRadius.circular(18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FriendPalette.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '闪讯号：${widget.user.flashId ?? 'flash_${widget.user.accountId}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FriendPalette.secondaryInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const FriendSectionTitle(title: '验证消息', caption: '一句简单的自我介绍，更容易通过验证'),
          FriendCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 200,
              maxLines: 5,
              minLines: 3,
              style: const TextStyle(
                color: FriendPalette.ink,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: '告诉对方你是谁…',
                hintStyle: TextStyle(
                  color: FriendPalette.mutedInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                counterStyle: TextStyle(
                  color: FriendPalette.mutedInk,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: FriendPalette.mutedInk,
                size: 16,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  '发送后，对方会在新的朋友中看到你的申请。',
                  style: TextStyle(
                    color: FriendPalette.mutedInk,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
