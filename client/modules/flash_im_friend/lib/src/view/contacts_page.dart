import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';
import 'add_friend_page.dart';
import 'friend_profile_page.dart';
import 'friend_search_page.dart';
import 'new_friends_page.dart';
import 'widgets/friend_avatar_tile.dart';
import 'widgets/friend_ui.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key, required this.onMessageFriend});

  final ValueChanged<FriendUser> onMessageFriend;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FriendPalette.background,
      child: BlocListener<FriendCubit, FriendState>(
        listenWhen: (previous, current) =>
            previous.actionMessage != current.actionMessage &&
            current.actionMessage != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                content: Text(state.actionMessage!),
              ),
            );
          context.read<FriendCubit>().clearActionMessage();
        },
        child: Column(
          children: [
            _ContactsHeader(
              onSearch: () => _pushWithCubit(
                context,
                FriendSearchPage(onMessageFriend: onMessageFriend),
              ),
              onAdd: () => _pushWithCubit(
                context,
                AddFriendPage(onMessageFriend: onMessageFriend),
              ),
            ),
            Expanded(
              child: BlocBuilder<FriendCubit, FriendState>(
                builder: (context, state) {
                  if (state.isLoading && state.friends.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: FriendPalette.primary,
                      ),
                    );
                  }
                  if (state.errorMessage != null && state.friends.isEmpty) {
                    return _ContactsError(message: state.errorMessage!);
                  }
                  return _ContactsBody(
                    state: state,
                    onMessageFriend: onMessageFriend,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsHeader extends StatelessWidget {
  const _ContactsHeader({required this.onSearch, required this.onAdd});

  final VoidCallback onSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: FriendPalette.background,
        border: Border(bottom: BorderSide(color: FriendPalette.border)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '通讯录',
                  style: TextStyle(
                    color: FriendPalette.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '和重要的人保持联系',
                  style: TextStyle(
                    color: FriendPalette.mutedInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 17,
            child: Row(
              children: [
                _HeaderAction(
                  tooltip: '搜索好友',
                  icon: Icons.search_rounded,
                  onPressed: onSearch,
                ),
                const SizedBox(width: 8),
                _HeaderAction(
                  tooltip: '添加朋友',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FriendPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FriendPalette.border),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        icon: Icon(icon, color: FriendPalette.ink, size: 21),
      ),
    );
  }
}

class _ContactsBody extends StatelessWidget {
  const _ContactsBody({required this.state, required this.onMessageFriend});

  final FriendState state;
  final ValueChanged<FriendUser> onMessageFriend;

  @override
  Widget build(BuildContext context) {
    final friends = [...state.friends]
      ..sort((left, right) => left.displayName.compareTo(right.displayName));

    return RefreshIndicator(
      color: FriendPalette.primary,
      backgroundColor: FriendPalette.surface,
      onRefresh: context.read<FriendCubit>().refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _NewFriendsEntry(
            count: state.pendingRequestCount,
            onTap: () => _pushWithCubit(context, const NewFriendsPage()),
          ),
          const SizedBox(height: 24),
          FriendSectionTitle(
            title: friends.isEmpty ? '通讯录' : '好友',
            caption: friends.isEmpty ? null : '${friends.length} 位联系人',
          ),
          if (friends.isEmpty)
            const FriendCard(
              child: FriendEmptyState(
                icon: Icons.people_alt_outlined,
                title: '还没有好友',
                message: '搜索账号，和重要的人建立联系',
              ),
            )
          else
            FriendCard(
              child: Column(
                children: [
                  for (var index = 0; index < friends.length; index += 1) ...[
                    FriendAvatarTile(
                      user: friends[index],
                      onTap: () => _pushWithCubit(
                        context,
                        FriendProfilePage(
                          user: friends[index],
                          onMessageFriend: onMessageFriend,
                        ),
                      ),
                    ),
                    if (index != friends.length - 1)
                      const Divider(
                        height: 1,
                        indent: 84,
                        endIndent: 16,
                        color: FriendPalette.border,
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NewFriendsEntry extends StatelessWidget {
  const _NewFriendsEntry({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FriendCard(
      emphasized: count > 0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                FriendIconBadge(
                  icon: Icons.person_add_alt_1_rounded,
                  color: FriendPalette.warning,
                  backgroundColor: FriendPalette.warningSoft,
                  count: count,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '新的朋友',
                        style: TextStyle(
                          color: FriendPalette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '查看好友申请与验证消息',
                        style: TextStyle(
                          color: FriendPalette.secondaryInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: FriendPalette.mutedInk,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactsError extends StatelessWidget {
  const _ContactsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: FriendPalette.mutedInk,
              size: 40,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FriendPalette.secondaryInk,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: context.read<FriendCubit>().load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重新加载'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FriendPalette.primary,
                side: const BorderSide(color: FriendPalette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<T?> _pushWithCubit<T>(BuildContext context, Widget page) {
  final cubit = context.read<FriendCubit>();
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      builder: (_) =>
          BlocProvider<FriendCubit>.value(value: cubit, child: page),
    ),
  );
}
