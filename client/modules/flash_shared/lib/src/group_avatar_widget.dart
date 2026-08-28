import 'package:flutter/material.dart';

import 'avatar_widget.dart';

const String groupAvatarPrefix = 'grid:';

String encodeGroupAvatar(Iterable<String> avatars) {
  final values = avatars
      .map((avatar) => avatar.trim())
      .where((avatar) => avatar.isNotEmpty)
      .take(9);
  return '$groupAvatarPrefix${values.join(',')}';
}

class GroupAvatarWidget extends StatelessWidget {
  const GroupAvatarWidget({
    super.key,
    required this.avatar,
    required this.seed,
    this.size = 52,
    this.borderRadius,
  });

  final String? avatar;
  final String seed;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final value = avatar?.trim() ?? '';
    final avatars = _parseGridAvatar(value);
    final radius = borderRadius ?? BorderRadius.circular(size * 0.29);
    if (avatars.isEmpty) {
      return AvatarWidget(
        avatar: value.startsWith(groupAvatarPrefix) ? null : value,
        seed: seed,
        size: size,
        borderRadius: radius,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: const Color(0xFFE8EBF2),
        child: SizedBox.square(
          dimension: size,
          child: avatars.length == 1
              ? _avatar(avatars.first, 0, size)
              : Padding(
                  padding: const EdgeInsets.all(2),
                  child: _GridLayout(
                    avatars: avatars,
                    seed: seed,
                    size: size - 4,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _avatar(String value, int index, double avatarSize) {
    return AvatarWidget(
      key: ValueKey('group-avatar-cell-$index'),
      avatar: value,
      seed: '$seed-$index',
      size: avatarSize,
      borderRadius: BorderRadius.zero,
    );
  }
}

class _GridLayout extends StatelessWidget {
  const _GridLayout({
    required this.avatars,
    required this.seed,
    required this.size,
  });

  final List<String> avatars;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final columnCount = avatars.length <= 4 ? 2 : 3;
    final rowCounts = _rowCounts(avatars.length, columnCount);
    final gap = size < 36 ? 1.0 : 2.0;
    final itemSize = (size - gap * (columnCount - 1)) / columnCount;
    var avatarIndex = 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var rowIndex = 0; rowIndex < rowCounts.length; rowIndex++) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (
                var columnIndex = 0;
                columnIndex < rowCounts[rowIndex];
                columnIndex++
              ) ...[
                if (columnIndex > 0) SizedBox(width: gap),
                _avatar(avatars[avatarIndex], avatarIndex++, itemSize),
              ],
            ],
          ),
          if (rowIndex < rowCounts.length - 1) SizedBox(height: gap),
        ],
      ],
    );
  }

  Widget _avatar(String value, int index, double avatarSize) {
    return AvatarWidget(
      key: ValueKey('group-avatar-cell-$index'),
      avatar: value,
      seed: '$seed-$index',
      size: avatarSize,
      borderRadius: BorderRadius.zero,
    );
  }
}

List<int> _rowCounts(int itemCount, int columnCount) {
  final fullRows = itemCount ~/ columnCount;
  final leadingCount = itemCount % columnCount;
  return [
    if (leadingCount > 0) leadingCount,
    for (var index = 0; index < fullRows; index++) columnCount,
  ];
}

List<String> _parseGridAvatar(String value) {
  if (!value.startsWith(groupAvatarPrefix)) return const [];
  return value
      .substring(groupAvatarPrefix.length)
      .split(',')
      .map((avatar) => avatar.trim())
      .where((avatar) => avatar.isNotEmpty)
      .take(9)
      .toList(growable: false);
}
