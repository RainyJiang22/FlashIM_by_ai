import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/friend_user.dart';
import '../logic/friend_cubit.dart';
import 'friend_search_page.dart';

class AddFriendPage extends StatelessWidget {
  const AddFriendPage({super.key, required this.onMessageFriend});

  final ValueChanged<FriendUser> onMessageFriend;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加朋友')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final cubit = context.read<FriendCubit>();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider<FriendCubit>.value(
                      value: cubit,
                      child: FriendSearchPage(onMessageFriend: onMessageFriend),
                    ),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, color: Color(0xFFAAAAAA), size: 26),
                    SizedBox(width: 8),
                    Text(
                      '搜索账号/手机号',
                      style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 17),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
