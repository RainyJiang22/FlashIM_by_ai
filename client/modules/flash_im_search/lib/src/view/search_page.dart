import 'dart:async';

import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/search_history_store.dart';
import '../data/search_models.dart';
import '../data/search_repository.dart';
import '../logic/search_cubit.dart';
import '../logic/search_state.dart';
import 'message_detail_page.dart';
import 'widgets/highlight_text.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    required this.onFriendTap,
    required this.onConversationTap,
  });

  final ValueChanged<FriendUser> onFriendTap;
  final ValueChanged<Conversation> onConversationTap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchCubit(
        repository: context.read<SearchRepository>(),
        historyStore: const SharedPreferencesSearchHistoryStore(),
      )..loadHistory(),
      child: _SearchView(
        onFriendTap: onFriendTap,
        onConversationTap: onConversationTap,
      ),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView({
    required this.onFriendTap,
    required this.onConversationTap,
  });

  final ValueChanged<FriendUser> onFriendTap;
  final ValueChanged<Conversation> onConversationTap;

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  final _expanded = <SearchSection>{};
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      backgroundColor: FlashPalette.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              key: const Key('comprehensive-search-field'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '搜索联系人、群聊和聊天记录',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: _onChanged,
              onSubmitted: _searchNow,
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) =>
                  state.keyword.isEmpty ? _history(state) : _results(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _history(SearchState state) {
    if (state.history.isEmpty) {
      return const Center(
        child: Text(
          '暂无搜索历史',
          style: TextStyle(color: FlashPalette.secondaryInk),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '搜索历史',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              key: const Key('clear-search-history'),
              onPressed: context.read<SearchCubit>().clearHistory,
              child: const Text('清空'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: state.history
              .map(
                (item) => ActionChip(
                  key: ValueKey('search-history-$item'),
                  avatar: const Icon(Icons.history_rounded, size: 17),
                  label: Text(item),
                  onPressed: () => _selectHistory(item),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _results(SearchState state) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        _section(
          section: SearchSection.friends,
          title: '联系人',
          state: state,
          total: state.friends.length,
          children: _visible(
            SearchSection.friends,
            state.friends,
          ).map(_friendTile).toList(growable: false),
        ),
        const SizedBox(height: 12),
        _section(
          section: SearchSection.groups,
          title: '群聊',
          state: state,
          total: state.groups.length,
          children: _visible(
            SearchSection.groups,
            state.groups,
          ).map(_groupTile).toList(growable: false),
        ),
        const SizedBox(height: 12),
        _section(
          section: SearchSection.messages,
          title: '聊天记录',
          state: state,
          total: state.messageGroups.length,
          children: _visible(SearchSection.messages, state.messageGroups)
              .map((group) => _messageGroupTile(group, state.keyword))
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _section({
    required SearchSection section,
    required String title,
    required SearchState state,
    required int total,
    required List<Widget> children,
  }) {
    final pending = state.isPending(section);
    final failed = state.hasFailed(section);
    return Container(
      key: ValueKey('search-section-${section.name}'),
      decoration: flashCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (pending)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (failed && total == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '加载失败',
                      style: TextStyle(color: FlashPalette.secondaryInk),
                    ),
                  ),
                  TextButton(
                    key: ValueKey('retry-search-${section.name}'),
                    onPressed: () =>
                        context.read<SearchCubit>().retrySection(section),
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          else if (!pending && total == 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                '暂无相关结果',
                style: TextStyle(color: FlashPalette.mutedInk),
              ),
            )
          else ...[
            ..._withDividers(children),
            if (total > 3)
              TextButton(
                key: ValueKey('toggle-search-${section.name}'),
                onPressed: () => setState(() {
                  if (!_expanded.add(section)) _expanded.remove(section);
                }),
                child: Text(_expanded.contains(section) ? '收起' : '查看更多'),
              ),
          ],
        ],
      ),
    );
  }

  Iterable<Widget> _withDividers(List<Widget> children) sync* {
    for (var index = 0; index < children.length; index++) {
      //if (index > 0) yield const Divider(height: 0, indent: 72);
      yield children[index];
    }
  }

  List<T> _visible<T>(SearchSection section, List<T> values) {
    return _expanded.contains(section)
        ? values
        : values.take(3).toList(growable: false);
  }

  Widget _friendTile(FriendUser friend) {
    return ListTile(
      key: ValueKey('friend-search-result-${friend.accountId}'),
      leading: AvatarWidget(
        avatar: friend.avatar,
        seed: '${friend.accountId}',
        size: 44,
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        friend.displayName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: friend.signature.trim().isEmpty
          ? null
          : Text(
              friend.signature,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: () => widget.onFriendTap(friend),
    );
  }

  Widget _groupTile(Conversation group) {
    return ListTile(
      key: ValueKey('group-search-result-${group.id}'),
      leading: GroupAvatarWidget(
        avatar: group.groupAvatar,
        seed: group.id,
        size: 44,
      ),
      title: Text(
        group.displayName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${group.memberCount} 位成员'),
      onTap: () => widget.onConversationTap(group),
    );
  }

  Widget _messageGroupTile(MessageSearchGroup group, String keyword) {
    final conversation = group.conversation;
    final preview = group.messages.isEmpty ? '' : group.messages.first.content;
    return ListTile(
      key: ValueKey('message-group-result-${conversation.id}'),
      leading: conversation.isGroupChat
          ? GroupAvatarWidget(
              avatar: conversation.groupAvatar,
              seed: conversation.id,
              size: 44,
            )
          : AvatarWidget(
              avatar: conversation.peerAvatar,
              seed: conversation.avatarSeed,
              size: 44,
              borderRadius: BorderRadius.circular(12),
            ),
      title: Text(
        '${conversation.displayName}（${group.matchCount}）',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: HighlightText(
        text: preview,
        keyword: keyword,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: FlashPalette.secondaryInk),
      ),
      onTap: () {
        if (group.matchCount == 1) {
          widget.onConversationTap(conversation);
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MessageDetailPage(
              group: group,
              keyword: keyword,
              onConversationTap: widget.onConversationTap,
            ),
          ),
        );
      },
    );
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchNow(value),
    );
  }

  void _searchNow(String value) {
    _debounce?.cancel();
    _expanded.clear();
    context.read<SearchCubit>().search(value);
  }

  void _selectHistory(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _searchNow(value);
  }
}
