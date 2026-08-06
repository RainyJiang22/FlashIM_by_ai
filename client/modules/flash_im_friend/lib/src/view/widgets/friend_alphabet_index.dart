import 'dart:async';

import 'package:flutter/material.dart';

import 'friend_sort.dart';
import 'friend_ui.dart';

class FriendAlphabetIndex extends StatefulWidget {
  const FriendAlphabetIndex({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<FriendAlphabetIndex> createState() => _FriendAlphabetIndexState();
}

class _FriendAlphabetIndexState extends State<FriendAlphabetIndex> {
  Timer? _clearActiveTimer;
  String? _activeLetter;
  bool _isDragging = false;

  @override
  void dispose() {
    _clearActiveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - 16;
        final barHeight = availableHeight
            .clamp(1.0, friendAlphabetLabels.length * 27.0)
            .toDouble();
        final rowHeight = barHeight / friendAlphabetLabels.length;
        final activeIndex = friendAlphabetLabels.indexOf(_activeLetter ?? '');

        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 36,
            height: barHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _selectAt(details.localPosition.dy, barHeight),
                  onVerticalDragStart: (details) {
                    setState(() => _isDragging = true);
                    _selectAt(details.localPosition.dy, barHeight);
                  },
                  onVerticalDragUpdate: (details) =>
                      _selectAt(details.localPosition.dy, barHeight),
                  onVerticalDragEnd: (_) => _finishInteraction(),
                  onTapUp: (_) => _finishInteraction(),
                  onTapCancel: _finishInteraction,
                  child: Column(
                    children: [
                      for (final letter in friendAlphabetLabels)
                        Expanded(
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: 21,
                              height: 21,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _activeLetter == letter
                                    ? FriendPalette.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                letter,
                                style: TextStyle(
                                  color: _activeLetter == letter
                                      ? Colors.white
                                      : FriendPalette.secondaryInk,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isDragging && activeIndex >= 0)
                  Positioned(
                    right: 40,
                    top: rowHeight * activeIndex + rowHeight / 2 - 27,
                    child: _AlphabetBubble(letter: _activeLetter!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectAt(double localDy, double barHeight) {
    final rawIndex = (localDy / barHeight * friendAlphabetLabels.length)
        .floor()
        .clamp(0, friendAlphabetLabels.length - 1)
        .toInt();
    final letter = friendAlphabetLabels[rawIndex];
    widget.onSelected(letter);
    _clearActiveTimer?.cancel();
    setState(() {
      _activeLetter = letter;
      _isDragging = true;
    });
  }

  void _finishInteraction() {
    if (!mounted) {
      return;
    }
    setState(() => _isDragging = false);
    _clearActiveTimer?.cancel();
    _clearActiveTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) {
        return;
      }
      setState(() => _activeLetter = null);
    });
  }
}

class _AlphabetBubble extends StatelessWidget {
  const _AlphabetBubble({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FriendPalette.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2417233B),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        width: 54,
        height: 54,
        child: Center(
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
