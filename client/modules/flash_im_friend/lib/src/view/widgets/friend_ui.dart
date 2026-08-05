import 'package:flutter/material.dart';

abstract final class FriendPalette {
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
  static const successSoft = Color(0xFFE8F8F1);
  static const warning = Color(0xFFE8902F);
  static const warningSoft = Color(0xFFFFF3E5);
  static const danger = Color(0xFFD95D6A);
  static const dangerSoft = Color(0xFFFFEEF0);
}

BoxDecoration friendCardDecoration({
  Color color = FriendPalette.surface,
  bool emphasized = false,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: FriendPalette.border),
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

class FriendCard extends StatelessWidget {
  const FriendCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.emphasized = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: friendCardDecoration(emphasized: emphasized),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }
}

class FriendSectionTitle extends StatelessWidget {
  const FriendSectionTitle({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
  });

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FriendPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                if (caption?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    caption!,
                    style: const TextStyle(
                      color: FriendPalette.mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ..._buildTrailing(),
        ],
      ),
    );
  }

  List<Widget> _buildTrailing() {
    final value = trailing;
    if (value == null) {
      return const [];
    }
    return [const SizedBox(width: 12), value];
  }
}

class FriendStatusPill extends StatelessWidget {
  const FriendStatusPill({
    super.key,
    required this.label,
    this.color = FriendPalette.secondaryInk,
    this.backgroundColor = const Color(0xFFF0F3F8),
    this.icon,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class FriendEmptyState extends StatelessWidget {
  const FriendEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: FriendPalette.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: FriendPalette.primary, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FriendPalette.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 7),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FriendPalette.secondaryInk,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FriendIconBadge extends StatelessWidget {
  const FriendIconBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.count = 0,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: FriendPalette.danger,
      alignment: Alignment.topRight,
      offset: const Offset(5, -5),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Icon(icon, color: color, size: 27),
      ),
    );
  }
}
