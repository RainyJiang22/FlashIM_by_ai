import 'package:flutter/material.dart';

abstract final class FlashPalette {
  static const background = Color(0xFFF6F8FC);
  static const surface = Colors.white;
  static const ink = Color(0xFF17233B);
  static const secondaryInk = Color(0xFF72809A);
  static const mutedInk = Color(0xFF9AA6B8);
  static const primary = Color(0xFF2C6BED);
  static const primaryDeep = Color(0xFF1F54C9);
  static const primarySoft = Color(0xFFEAF1FF);
  static const border = Color(0xFFE4EAF3);
  static const success = Color(0xFF1DAA72);
  static const warning = Color(0xFFE8902F);
  static const danger = Color(0xFFD95D6A);
}

BoxDecoration flashCardDecoration({
  Color color = FlashPalette.surface,
  bool emphasized = false,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: FlashPalette.border),
    boxShadow: emphasized
        ? const [
            BoxShadow(
              color: Color(0x0D1D3B6D),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ]
        : null,
  );
}
