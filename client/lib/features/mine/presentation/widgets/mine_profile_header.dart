import 'package:flutter/material.dart';

import '../../../auth/domain/auth_profile.dart';

class MineProfileHeader extends StatelessWidget {
  const MineProfileHeader({super.key, required this.profile});

  final AuthProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0xFFEAF1FF),
          backgroundImage: NetworkImage(profile.avatarUrl),
        ),
        const SizedBox(height: 16),
        Text(
          profile.nickname,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2A42),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          profile.phone,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6A7B92)),
        ),
      ],
    );
  }
}
