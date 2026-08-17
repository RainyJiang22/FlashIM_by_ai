import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.avatars,
    required this.seed,
    this.size = 52,
  });

  final List<String> avatars;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visible = avatars
        .where((avatar) => avatar.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
    if (visible.isEmpty) {
      return AvatarWidget(
        avatar: null,
        seed: seed,
        size: size,
        borderRadius: BorderRadius.circular(size * 0.29),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.29),
      child: ColoredBox(
        color: const Color(0xFFE8EBF2),
        child: SizedBox.square(
          dimension: size,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: _AvatarGrid(avatars: visible, seed: seed, size: size - 4),
          ),
        ),
      ),
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({
    required this.avatars,
    required this.seed,
    required this.size,
  });

  final List<String> avatars;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatars.length == 1) {
      return _avatar(avatars.first, size);
    }
    if (avatars.length == 2) {
      final itemSize = (size - 2) / 2;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _avatar(avatars[0], itemSize),
          const SizedBox(width: 2),
          _avatar(avatars[1], itemSize),
        ],
      );
    }

    final itemSize = (size - 2) / 2;
    final top = avatars.length == 3
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_avatar(avatars[0], itemSize)],
          )
        : Row(
            children: [
              _avatar(avatars[0], itemSize),
              const SizedBox(width: 2),
              _avatar(avatars[1], itemSize),
            ],
          );
    final bottomStart = avatars.length == 3 ? 1 : 2;
    return Column(
      children: [
        top,
        const SizedBox(height: 2),
        Row(
          children: [
            _avatar(avatars[bottomStart], itemSize),
            const SizedBox(width: 2),
            _avatar(avatars[bottomStart + 1], itemSize),
          ],
        ),
      ],
    );
  }

  Widget _avatar(String avatar, double avatarSize) {
    return AvatarWidget(
      avatar: avatar,
      seed: '$seed-$avatar',
      size: avatarSize,
      borderRadius: BorderRadius.zero,
    );
  }
}
