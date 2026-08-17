import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class PrivateChatDetailsPage extends StatelessWidget {
  const PrivateChatDetailsPage({
    super.key,
    required this.friend,
    required this.onInviteMore,
  });

  final FriendUser friend;
  final Future<void> Function(FriendUser friend) onInviteMore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('聊天详情')),
      backgroundColor: FlashPalette.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: flashCardDecoration(),
              child: Row(
                children: [
                  AvatarWidget(
                    avatar: friend.avatar,
                    seed: friend.accountId.toString(),
                    size: 56,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      friend.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('invite-more-to-group'),
              onPressed: () => onInviteMore(friend),
              icon: const Icon(Icons.group_add_rounded),
              label: const Text('邀请更多人发起群聊'),
            ),
          ],
        ),
      ),
    );
  }
}
