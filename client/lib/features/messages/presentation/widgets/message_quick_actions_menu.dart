import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class MessageQuickAction {
  const MessageQuickAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class MessageQuickActionsMenu extends StatelessWidget {
  const MessageQuickActionsMenu({super.key, required this.actions});

  final List<MessageQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      key: const Key('messages-quick-actions-anchor'),
      alignmentOffset: const Offset(-128, 8),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(FlashPalette.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: FlashPalette.border),
          ),
        ),
        shadowColor: const WidgetStatePropertyAll(Color(0x1A172E59)),
      ),
      menuChildren: actions
          .map(
            (action) => MenuItemButton(
              key: Key('message-quick-action-${action.id}'),
              onPressed: action.onTap,
              leadingIcon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: FlashPalette.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: FlashPalette.primary, size: 19),
              ),
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(166, 48)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              child: Text(
                action.label,
                style: const TextStyle(
                  color: FlashPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(growable: false),
      builder: (context, controller, _) => IconButton(
        key: const Key('messages-create-group'),
        tooltip: '更多',
        onPressed: controller.isOpen ? controller.close : controller.open,
        style: IconButton.styleFrom(
          backgroundColor: FlashPalette.surface,
          side: const BorderSide(color: FlashPalette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: Icon(
          controller.isOpen ? Icons.close_rounded : Icons.add_rounded,
          color: FlashPalette.ink,
        ),
      ),
    );
  }
}
