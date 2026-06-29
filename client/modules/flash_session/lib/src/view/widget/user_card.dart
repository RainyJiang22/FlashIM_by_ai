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
        borderRadius: BorderRadius.circular(size * 0.12),
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

    return IdenticonAvatar(
      seed: user.identiconSeed,
      size: size,
      borderRadius: BorderRadius.circular(size * 0.12),
    );
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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 38, 22, 34),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(user: user, size: 74),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.nickname,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '闪讯号：${user.userId}',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        color: Color(0xFF7A7A7A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      signature,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        color: user.signature.trim().isEmpty
                            ? const Color(0xFFA0A0A0)
                            : const Color(0xFF7A7A7A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC7C7C7),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
