import 'package:flutter/material.dart';

import 'identicon_avatar.dart';

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.avatar,
    required this.seed,
    this.size = 48,
    this.borderRadius,
  });

  final String? avatar;
  final String seed;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final value = avatar?.trim();
    if (value == null || value.isEmpty) {
      return _identicon(seed);
    }

    if (value.startsWith('identicon:')) {
      final identiconSeed = value.substring('identicon:'.length).trim();
      return _identicon(identiconSeed.isEmpty ? seed : identiconSeed);
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
        child: Image.network(
          value,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _identicon(seed),
        ),
      );
    }

    return _identicon(value);
  }

  Widget _identicon(String value) {
    return IdenticonAvatar(seed: value, size: size, borderRadius: borderRadius);
  }
}
