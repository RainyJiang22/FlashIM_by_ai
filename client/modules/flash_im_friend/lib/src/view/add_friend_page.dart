import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import 'friend_search_page.dart';
import 'widgets/friend_ui.dart';

class AddFriendPage extends StatelessWidget {
  const AddFriendPage({super.key, required this.onMessageFriend});

  final ValueChanged<FriendUser> onMessageFriend;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FriendPalette.background,
      appBar: AppBar(
        backgroundColor: FriendPalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: FriendPalette.ink,
        title: const Text('添加朋友'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEAF1FF), Color(0xFFF3F7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDDE8FC)),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: FriendPalette.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.connect_without_contact_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '找到你的朋友',
                        style: TextStyle(
                          color: FriendPalette.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        '输入闪讯号或手机号，快速找到熟悉的人',
                        style: TextStyle(
                          color: FriendPalette.secondaryInk,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const FriendSectionTitle(title: '添加方式', caption: '通过账号搜索并发送好友验证'),
          FriendCard(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openSearch(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: FriendPalette.primarySoft,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: FriendPalette.primary,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '搜索账号 / 手机号',
                              style: TextStyle(
                                color: FriendPalette.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '找到后可查看资料并发送验证消息',
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
          ),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    final cubit = context.read<FriendCubit>();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<FriendCubit>.value(
          value: cubit,
          child: FriendSearchPage(onMessageFriend: onMessageFriend),
        ),
      ),
    );
  }
}
