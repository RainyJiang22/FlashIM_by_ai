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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1D3B6D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 18, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: UserAvatar(user: user, size: 74),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.nickname,
                          style: const TextStyle(
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17233B),
                          ),
                        ),
                        const SizedBox(height: 11),
                        Text(
                          '闪讯号：${user.userId}',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            color: Color(0xFF72809A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          signature,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: user.signature.trim().isEmpty
                                ? const Color(0xFF9AA6B8)
                                : const Color(0xFF72809A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF9AA6B8),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
