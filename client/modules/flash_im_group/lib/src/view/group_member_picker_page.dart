import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'widgets/selectable_friend_tile.dart';
import 'widgets/selected_friend_strip.dart';

class GroupMemberPickerPage extends StatefulWidget {
  const GroupMemberPickerPage({super.key, required this.existingMemberIds});

  final Set<int> existingMemberIds;

  @override
  State<GroupMemberPickerPage> createState() => _GroupMemberPickerPageState();
}

class _GroupMemberPickerPageState extends State<GroupMemberPickerPage> {
  var _friends = const <FriendUser>[];
  var _selectedIds = <int>{};
  var _query = '';
  var _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final loaded = await context.read<FriendRepository>().getFriends();
      if (!mounted) return;
      setState(() {
        _friends = loaded
            .where(
              (friend) => !widget.existingMemberIds.contains(friend.accountId),
            )
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '好友列表加载失败，请稍后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _query.trim().toLowerCase();
    final visible = _friends
        .where((friend) {
          return keyword.isEmpty ||
              friend.displayName.toLowerCase().contains(keyword) ||
              (friend.flashId?.toLowerCase().contains(keyword) ?? false);
        })
        .toList(growable: false);
    final sections = buildFriendSections(visible);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择联系人'),
        actions: [
          TextButton(
            key: const Key('group-member-picker-submit'),
            onPressed: _selectedIds.isEmpty
                ? null
                : () => Navigator.of(context).pop(
                    _friends
                        .where(
                          (friend) => _selectedIds.contains(friend.accountId),
                        )
                        .toList(growable: false),
                  ),
            child: Text('完成(${_selectedIds.length})'),
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
              key: const Key('group-member-picker-search'),
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: '搜索好友',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SelectedFriendStrip(
            friends: _friends,
            selectedIds: _selectedIds,
            lockedIds: const {},
            onRemove: _toggle,
          ),
          Expanded(child: _body(sections)),
        ],
      ),
    );
  }

  Widget _body(List<FriendSection> sections) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_error!),
        ),
      );
    }
    if (sections.isEmpty) {
      return const Center(child: Text('没有可添加的好友'));
    }
    return ListView(
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              section.letter,
              style: const TextStyle(
                color: FlashPalette.secondaryInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final friend in section.friends)
            SelectableFriendTile(
              friend: friend,
              isSelected: _selectedIds.contains(friend.accountId),
              isLocked: false,
              onTap: () => _toggle(friend),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _toggle(FriendUser friend) {
    setState(() {
      final selected = Set<int>.of(_selectedIds);
      if (!selected.remove(friend.accountId)) selected.add(friend.accountId);
      _selectedIds = selected;
    });
  }
}
