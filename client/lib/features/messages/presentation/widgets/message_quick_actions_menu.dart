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
      alignmentOffset: const Offset(-164, 8),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xFF4A4A4A)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(10),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        shadowColor: const WidgetStatePropertyAll(Color(0x3317233B)),
      ),
      menuChildren: actions
          .expand<Widget>(
            (action) => [
              MenuItemButton(
                key: Key('message-quick-action-${action.id}'),
                onPressed: action.onTap,
                leadingIcon: Icon(action.icon, color: Colors.white, size: 28),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(210, 58)),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 20),
                  ),
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
                  overlayColor: WidgetStatePropertyAll(Color(0x1AFFFFFF)),
                ),
                child: Text(
                  action.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (action != actions.last)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: Color(0x40FFFFFF)),
                ),
            ],
          )
          .toList(growable: false),
      builder: (context, controller, _) => IconButton(
        key: const Key('messages-create-group'),
        tooltip: '更多',
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: Icon(
          controller.isOpen ? Icons.close_rounded : Icons.add_rounded,
          color: FlashPalette.ink,
          size: 28,
        ),
      ),
    );
  }
}
