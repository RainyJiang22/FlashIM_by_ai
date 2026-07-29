import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';

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
      appBar: AppBar(
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
                child: processing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('发送'),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 200,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: '我是…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF3B82F6)),
            ),
          ),
        ),
      ),
    );
  }
}
