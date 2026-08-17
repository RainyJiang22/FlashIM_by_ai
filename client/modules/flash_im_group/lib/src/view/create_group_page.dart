import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../logic/create_group_cubit.dart';
import '../logic/create_group_state.dart';
import 'widgets/group_feedback_view.dart';
import 'widgets/selectable_friend_tile.dart';
import 'widgets/selected_friend_strip.dart';

class CreateGroupPage extends StatelessWidget {
  const CreateGroupPage({super.key, this.initialMembers = const []});

  final List<FriendUser> initialMembers;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CreateGroupCubit(
        friendRepository: context.read<FriendRepository>(),
        conversationRepository: context.read<ConversationRepository>(),
        initialMembers: initialMembers,
      )..loadFriends(),
      child: const _CreateGroupView(),
    );
  }
}

class _CreateGroupView extends StatelessWidget {
  const _CreateGroupView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateGroupCubit, CreateGroupState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('发起群聊'),
            actions: [
              TextButton(
                key: const Key('create-group-submit'),
                onPressed: state.canCreate
                    ? () async {
                        final conversation = await context
                            .read<CreateGroupCubit>()
                            .createGroup();
                        if (conversation != null && context.mounted) {
                          Navigator.of(context).pop(conversation);
                        }
                      }
                    : null,
                child: state.isCreating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('完成(${state.selectedCount})'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          backgroundColor: FlashPalette.background,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  key: const Key('create-group-search'),
                  onChanged: context.read<CreateGroupCubit>().updateQuery,
                  decoration: const InputDecoration(
                    hintText: '搜索好友',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              SelectedFriendStrip(
                friends: state.friends,
                selectedIds: state.selectedIds,
                lockedIds: state.lockedIds,
                onRemove: context.read<CreateGroupCubit>().toggleFriend,
              ),
              Expanded(child: _FriendSelectionBody(state: state)),
            ],
          ),
        );
      },
    );
  }
}

class _FriendSelectionBody extends StatelessWidget {
  const _FriendSelectionBody({required this.state});

  final CreateGroupState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.friends.isEmpty) {
      return GroupFeedbackView(
        icon: Icons.cloud_off_rounded,
        message: state.errorMessage!,
        actionLabel: '重试',
        onAction: context.read<CreateGroupCubit>().loadFriends,
      );
    }
    final sections = buildFriendSections(state.visibleFriends);
    if (sections.isEmpty) {
      return const GroupFeedbackView(
        icon: Icons.person_search_rounded,
        message: '没有找到好友',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sections.fold<int>(
        0,
        (count, item) => count + item.friends.length + 1,
      ),
      itemBuilder: (context, index) {
        var cursor = index;
        for (final section in sections) {
          if (cursor == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                section.letter,
                style: const TextStyle(
                  color: FlashPalette.secondaryInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          cursor -= 1;
          if (cursor < section.friends.length) {
            final friend = section.friends[cursor];
            return SelectableFriendTile(
              friend: friend,
              isSelected: state.selectedIds.contains(friend.accountId),
              isLocked: state.lockedIds.contains(friend.accountId),
              onTap: () =>
                  context.read<CreateGroupCubit>().toggleFriend(friend),
            );
          }
          cursor -= section.friends.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}
