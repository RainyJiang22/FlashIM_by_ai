import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';
import 'add_friend_page.dart';
import 'friend_profile_page.dart';
import 'friend_search_page.dart';
import 'new_friends_page.dart';
import 'widgets/friend_alphabet_index.dart';
import 'widgets/friend_avatar_tile.dart';
import 'widgets/friend_sort.dart';
import 'widgets/friend_ui.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({
    super.key,
    required this.onMessageFriend,
    required this.onOpenGroups,
    required this.onSearchGroups,
    required this.onOpenGroupNotifications,
    required this.groupNotificationCount,
  });

  final ValueChanged<FriendUser> onMessageFriend;
  final VoidCallback onOpenGroups;
  final VoidCallback onSearchGroups;
  final VoidCallback onOpenGroupNotifications;
  final int groupNotificationCount;

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
                AddFriendPage(
                  onMessageFriend: onMessageFriend,
                  onSearchGroups: onSearchGroups,
                ),
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
                    onOpenGroups: onOpenGroups,
                    onOpenGroupNotifications: onOpenGroupNotifications,
                    groupNotificationCount: groupNotificationCount,
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
  const _ContactsBody({
    required this.state,
    required this.onMessageFriend,
    required this.onOpenGroups,
    required this.onOpenGroupNotifications,
    required this.groupNotificationCount,
  });

  final FriendState state;
  final ValueChanged<FriendUser> onMessageFriend;
  final VoidCallback onOpenGroups;
  final VoidCallback onOpenGroupNotifications;
  final int groupNotificationCount;

  @override
  Widget build(BuildContext context) {
    final friends = List<FriendUser>.of(state.friends);

    return _AlphabeticalContactsList(
      friends: friends,
      pendingRequestCount: state.pendingRequestCount,
      onRefresh: context.read<FriendCubit>().refresh,
      onMessageFriend: onMessageFriend,
      onOpenNewFriends: () => _pushWithCubit(context, const NewFriendsPage()),
      onOpenGroups: onOpenGroups,
      onOpenGroupNotifications: onOpenGroupNotifications,
      groupNotificationCount: groupNotificationCount,
    );
  }
}

class _AlphabeticalContactsList extends StatefulWidget {
  const _AlphabeticalContactsList({
    required this.friends,
    required this.pendingRequestCount,
    required this.onRefresh,
    required this.onMessageFriend,
    required this.onOpenNewFriends,
    required this.onOpenGroups,
    required this.onOpenGroupNotifications,
    required this.groupNotificationCount,
  });

  final List<FriendUser> friends;
  final int pendingRequestCount;
  final Future<void> Function() onRefresh;
  final ValueChanged<FriendUser> onMessageFriend;
  final VoidCallback onOpenNewFriends;
  final VoidCallback onOpenGroups;
  final VoidCallback onOpenGroupNotifications;
  final int groupNotificationCount;

  @override
  State<_AlphabeticalContactsList> createState() =>
      _AlphabeticalContactsListState();
}

class _AlphabeticalContactsListState extends State<_AlphabeticalContactsList> {
  final ScrollController _scrollController = ScrollController();
  Map<String, GlobalKey> _sectionKeys = const {};
  List<FriendSection> _sections = const [];

  @override
  void initState() {
    super.initState();
    _updateSections(widget.friends);
  }

  @override
  void didUpdateWidget(covariant _AlphabeticalContactsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friends != widget.friends) {
      _updateSections(widget.friends);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFriends = _sections.isNotEmpty;

    return RefreshIndicator(
      color: FriendPalette.primary,
      backgroundColor: FriendPalette.surface,
      onRefresh: widget.onRefresh,
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 44, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NewFriendsEntry(
                  count: widget.pendingRequestCount,
                  onTap: widget.onOpenNewFriends,
                ),
                const SizedBox(height: 10),
                _GroupNotificationsEntry(
                  count: widget.groupNotificationCount,
                  onTap: widget.onOpenGroupNotifications,
                ),
                const SizedBox(height: 10),
                _GroupsEntry(onTap: widget.onOpenGroups),
                const SizedBox(height: 24),
                FriendSectionTitle(
                  title: hasFriends ? '好友' : '通讯录',
                  caption: hasFriends ? '${widget.friends.length} 位联系人' : null,
                  hasFriends: hasFriends,
                ),
                if (!hasFriends)
                  const FriendCard(
                    child: FriendEmptyState(
                      icon: Icons.people_alt_outlined,
                      title: '还没有好友',
                      message: '搜索账号，和重要的人建立联系',
                    ),
                  )
                else
                  FriendCard(child: _buildFriendGroups(context)),
              ],
            ),
          ),
          if (hasFriends)
            Positioned.fill(
              child: FriendAlphabetIndex(onSelected: _jumpToLetter),
            ),
        ],
      ),
    );
  }

  Widget _buildFriendGroups(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in _sections) ...[
          Container(
            key: _sectionKeys[section.letter],
            height: 32,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: FriendPalette.background,
            child: Text(
              section.letter,
              style: const TextStyle(
                color: FriendPalette.primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (var index = 0; index < section.friends.length; index += 1) ...[
            FriendAvatarTile(
              user: section.friends[index],
              onTap: () => _openFriendProfile(context, section.friends[index]),
            ),
            if (index != section.friends.length - 1)
              const Divider(
                height: 1,
                indent: 84,
                endIndent: 16,
                color: FriendPalette.border,
              ),
          ],
        ],
      ],
    );
  }

  void _updateSections(Iterable<FriendUser> friends) {
    final sections = buildFriendSections(friends);
    final oldKeys = _sectionKeys;
    _sections = sections;
    _sectionKeys = {
      for (final section in sections)
        section.letter:
            oldKeys[section.letter] ?? GlobalKey(debugLabel: section.letter),
    };
  }

  void _openFriendProfile(BuildContext context, FriendUser friend) {
    _pushWithCubit(
      context,
      FriendProfilePage(user: friend, onMessageFriend: widget.onMessageFriend),
    );
  }

  void _jumpToLetter(String selectedLetter) {
    if (_sections.isEmpty) {
      return;
    }

    final target = _findSection(selectedLetter);
    final targetContext = _sectionKeys[target.letter]?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.02,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (!_scrollController.hasClients) {
      return;
    }
    final targetIndex = _sections.indexOf(target);
    final estimatedOffset =
        _scrollController.position.maxScrollExtent *
        (targetIndex / _sections.length);
    _scrollController.animateTo(
      estimatedOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  FriendSection _findSection(String selectedLetter) {
    if (selectedLetter == '#') {
      for (final section in _sections) {
        if (section.letter == '#') {
          return section;
        }
      }
      return _sections.last;
    }
    for (final section in _sections) {
      if (section.letter == selectedLetter ||
          section.letter.compareTo(selectedLetter) > 0) {
        return section;
      }
    }
    return _sections.last;
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

class _GroupsEntry extends StatelessWidget {
  const _GroupsEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FriendCard(
      child: ListTile(
        key: const Key('contacts-groups-entry'),
        onTap: onTap,
        leading: const FriendIconBadge(
          icon: Icons.groups_rounded,
          color: FriendPalette.primary,
          backgroundColor: FriendPalette.primarySoft,
        ),
        title: const Text('群聊', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('查看我加入的群聊'),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }
}

class _GroupNotificationsEntry extends StatelessWidget {
  const _GroupNotificationsEntry({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FriendCard(
      emphasized: count > 0,
      child: ListTile(
        key: const Key('contacts-group-notifications-entry'),
        onTap: onTap,
        leading: FriendIconBadge(
          icon: Icons.notifications_rounded,
          color: FriendPalette.primary,
          backgroundColor: FriendPalette.primarySoft,
          count: count,
        ),
        title: const Text('群通知', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('查看和处理入群申请'),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
