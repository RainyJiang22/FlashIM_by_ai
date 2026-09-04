import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class HighlightText extends StatelessWidget {
  const HighlightText({
    super.key,
    required this.text,
    required this.keyword,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final String keyword;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(children: _spans(baseStyle)),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<InlineSpan> _spans(TextStyle baseStyle) {
    final needle = keyword.trim();
    if (needle.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    final lowerText = text.toLowerCase();
    final lowerNeedle = needle.toLowerCase();
    final spans = <InlineSpan>[];
    var start = 0;
    while (start < text.length) {
      final match = lowerText.indexOf(lowerNeedle, start);
      if (match < 0) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (match > start) {
        spans.add(
          TextSpan(text: text.substring(start, match), style: baseStyle),
        );
      }
      final end = match + lowerNeedle.length;
      spans.add(
        TextSpan(
          text: text.substring(match, end),
          style:
              highlightStyle ??
              baseStyle.copyWith(
                color: FlashPalette.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
      );
      start = end;
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text, style: baseStyle));
    return spans;
  }
}
