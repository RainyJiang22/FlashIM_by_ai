import 'package:flutter/material.dart';

import '../../data/user.dart';
import 'identicon_avatar.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 56});

  final User user;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (user.hasCustomAvatar) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          user.avatar,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              IdenticonAvatar(seed: user.identiconSeed, size: size),
        ),
      );
    }

    return IdenticonAvatar(seed: user.identiconSeed, size: size);
  }
}

class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user, this.onTap});

  final User user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final signature = user.signature.trim().isEmpty ? '添加个性签名' : user.signature;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              UserAvatar(user: user, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nickname,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2A42),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '闪讯号 ${user.userId}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6A7B92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      signature,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: user.signature.trim().isEmpty
                            ? const Color(0xFF98A7BA)
                            : const Color(0xFF44556C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF98A7BA),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
