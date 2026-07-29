import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import '../logic/friend_state.dart';
import 'friend_profile_page.dart';
import 'widgets/friend_avatar_tile.dart';

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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 18,
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: '搜索账号/手机号',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
      body: BlocBuilder<FriendCubit, FriendState>(
        builder: (context, state) {
          if (state.isSearching) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null && _hasSearched) {
            return Center(child: Text(state.errorMessage!));
          }
          if (!_hasSearched) {
            return const SizedBox.shrink();
          }
          if (state.searchResults.isEmpty) {
            return const Center(
              child: Text(
                '未找到匹配的用户',
                style: TextStyle(color: Color(0xFF8A8A8A)),
              ),
            );
          }
          return ListView.separated(
            itemCount: state.searchResults.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) {
              final user = state.searchResults[index];
              return FriendAvatarTile(
                user: user,
                subtitle: _relationLabel(user),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFB0B0B0),
                ),
                onTap: () {
                  final cubit = context.read<FriendCubit>();
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider<FriendCubit>.value(
                        value: cubit,
                        child: FriendProfilePage(
                          user: user,
                          onMessageFriend: widget.onMessageFriend,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
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
