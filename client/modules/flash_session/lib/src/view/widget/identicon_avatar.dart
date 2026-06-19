import 'dart:math' as math;

import 'package:flutter/material.dart';

class IdenticonAvatar extends StatelessWidget {
  const IdenticonAvatar({
    super.key,
    required this.seed,
    this.size = 48,
    this.borderRadius,
  });

  final String seed;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size / 2);
    return ClipRRect(
      borderRadius: radius,
      child: CustomPaint(
        size: Size.square(size),
        painter: _IdenticonPainter(seed),
      ),
    );
  }
}

class _IdenticonPainter extends CustomPainter {
  const _IdenticonPainter(this.seed);

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final hash = _hashSeed(seed);
    final backgroundPaint = Paint()..color = _backgroundColor(hash);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final padding = size.width * 0.15;
    final gridSize = size.width - padding * 2;
    final cellSize = gridSize / 5;
    final foregroundPaint = Paint()..color = _foregroundColor(hash);

    for (var row = 0; row < 5; row += 1) {
      for (var col = 0; col < 3; col += 1) {
        final bitIndex = row * 3 + col;
        final isFilled = ((hash >> bitIndex) & 1) == 1;
        if (!isFilled) {
          continue;
        }

        final left = padding + col * cellSize;
        final top = padding + row * cellSize;
        canvas.drawRect(
          Rect.fromLTWH(left, top, cellSize, cellSize),
          foregroundPaint,
        );

        final mirrorCol = 4 - col;
        if (mirrorCol != col) {
          final mirrorLeft = padding + mirrorCol * cellSize;
          canvas.drawRect(
            Rect.fromLTWH(mirrorLeft, top, cellSize, cellSize),
            foregroundPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IdenticonPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }

  Color _backgroundColor(int hash) {
    return Color.lerp(
          Colors.white,
          const Color(0xFFEAF1FF),
          0.72 + ((hash >> 8) & 0xF) / 100,
        ) ??
        const Color(0xFFEAF1FF);
  }

  Color _foregroundColor(int hash) {
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.58, 0.72).toColor();
  }

  int _hashSeed(String value) {
    var hash = 5381;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash << 5) + hash + codeUnit) & 0x7fffffff;
    }
    return math.max(hash, 1);
  }
}
