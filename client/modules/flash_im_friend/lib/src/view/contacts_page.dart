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

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key, required this.onMessageFriend});

  final ValueChanged<FriendUser> onMessageFriend;

  @override
  Widget build(BuildContext context) {
    return BlocListener<FriendCubit, FriendState>(
      listenWhen: (previous, current) =>
          previous.actionMessage != current.actionMessage &&
          current.actionMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.actionMessage!)));
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
                  return const Center(child: CircularProgressIndicator());
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
    );
  }
}

class _ContactsHeader extends StatelessWidget {
  const _ContactsHeader({required this.onSearch, required this.onAdd});

  final VoidCallback onSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFEDEDED),
        border: Border(
          bottom: BorderSide(color: Color(0xFFDCDCDC), width: 0.6),
        ),
      ),
      child: SizedBox(
        width: 365,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              '通讯录',
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            Positioned(
              right: 6,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '搜索好友',
                    onPressed: onSearch,
                    icon: const Icon(Icons.search, size: 29),
                  ),
                  IconButton(
                    tooltip: '添加朋友',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle_outline, size: 29),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      onRefresh: context.read<FriendCubit>().refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _NewFriendsEntry(
            count: state.pendingRequestCount,
            onTap: () => _pushWithCubit(context, const NewFriendsPage()),
          ),
          if (friends.isNotEmpty)
            const _SectionLabel(label: '好友')
          else
            const _SectionLabel(label: '通讯录'),
          if (friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(
                child: Text(
                  '暂无好友，点击右上角添加朋友',
                  style: TextStyle(color: Color(0xFF8A8A8A)),
                ),
              ),
            )
          else
            ...List.generate(friends.length, (index) {
              final friend = friends[index];
              return Column(
                children: [
                  FriendAvatarTile(
                    user: friend,
                    onTap: () => _pushWithCubit(
                      context,
                      FriendProfilePage(
                        user: friend,
                        onMessageFriend: onMessageFriend,
                      ),
                    ),
                  ),
                  if (index != friends.length - 1)
                    const Divider(height: 1, indent: 80),
                ],
              );
            }),
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
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Badge(
                isLabelVisible: count > 0,
                label: Text(count > 99 ? '99+' : '$count'),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA33B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  '新的朋友',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 7),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF7A7A7A), fontSize: 13),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: Color(0xFFE35D6A))),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: context.read<FriendCubit>().load,
            child: const Text('重试'),
          ),
        ],
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
