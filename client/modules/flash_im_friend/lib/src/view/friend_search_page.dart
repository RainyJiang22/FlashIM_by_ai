import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';
import 'friend_profile_page.dart';
import 'widgets/friend_avatar_tile.dart';
import 'widgets/friend_ui.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key, required this.onMessageFriend});

  final ValueChanged<FriendUser> onMessageFriend;

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) {
      return;
    }
    setState(() => _hasSearched = true);
    await context.read<FriendCubit>().search(keyword);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FriendPalette.background,
      appBar: AppBar(
        backgroundColor: FriendPalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: FriendPalette.ink,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        titleSpacing: 0,
        title: SizedBox(
          height: 44,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            style: const TextStyle(
              color: FriendPalette.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '搜索账号 / 手机号',
              hintStyle: const TextStyle(
                color: FriendPalette.mutedInk,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: FriendPalette.secondaryInk,
                size: 21,
              ),
              filled: true,
              fillColor: FriendPalette.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: FriendPalette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: FriendPalette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: FriendPalette.primary,
                  width: 1.3,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: FriendPalette.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('取消'),
          ),
        ],
      ),
      body: BlocBuilder<FriendCubit, FriendState>(
        builder: (context, state) {
          if (state.isSearching) {
            return const Center(
              child: CircularProgressIndicator(color: FriendPalette.primary),
            );
          }
          if (state.errorMessage != null && _hasSearched) {
            return _SearchError(message: state.errorMessage!);
          }
          if (!_hasSearched) {
            return const _SearchIntro();
          }
          if (state.searchResults.isEmpty) {
            return const _SearchEmpty();
          }
          return _SearchResults(
            users: state.searchResults,
            onMessageFriend: widget.onMessageFriend,
          );
        },
      ),
    );
  }
}

class _SearchIntro extends StatelessWidget {
  const _SearchIntro();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: const [
        FriendCard(
          child: FriendEmptyState(
            icon: Icons.manage_search_rounded,
            title: '搜索你的朋友',
            message: '输入闪讯号或手机号，找到后即可查看资料',
          ),
        ),
      ],
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: const [
        FriendCard(
          child: FriendEmptyState(
            icon: Icons.person_search_rounded,
            title: '没有找到匹配的用户',
            message: '试试检查账号或手机号是否正确',
          ),
        ),
      ],
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FriendCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: FriendPalette.mutedInk,
                size: 38,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FriendPalette.secondaryInk,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.users, required this.onMessageFriend});

  final List<FriendUser> users;
  final ValueChanged<FriendUser> onMessageFriend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        FriendSectionTitle(title: '搜索结果', caption: '找到 ${users.length} 位用户'),
        FriendCard(
          child: Column(
            children: [
              for (var index = 0; index < users.length; index += 1) ...[
                FriendAvatarTile(
                  user: users[index],
                  subtitle: _relationLabel(users[index]),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: FriendPalette.mutedInk,
                    size: 15,
                  ),
                  onTap: () => _openProfile(context, users[index]),
                ),
                if (index != users.length - 1)
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
    );
  }

  void _openProfile(BuildContext context, FriendUser user) {
    final cubit = context.read<FriendCubit>();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<FriendCubit>.value(
          value: cubit,
          child: FriendProfilePage(
            user: user,
            onMessageFriend: onMessageFriend,
          ),
        ),
      ),
    );
  }
}

String? _relationLabel(FriendUser user) {
  if (user.isFriend) {
    return '已是好友';
  }
  if (user.isPendingSent) {
    return '等待验证';
  }
  if (user.isPendingReceived) {
    return '对方请求添加你为好友';
  }
  return user.signature.trim().isEmpty ? null : user.signature;
}
