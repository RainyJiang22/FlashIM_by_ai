import 'package:flutter/material.dart';

import 'demos/conversation/presentation/conversation_playground_page.dart';
import 'demos/fireworks/fireworks_show_page.dart';

class PlaygroundHomePage extends StatelessWidget {
  const PlaygroundHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF120B2E), Color(0xFF08111F), Color(0xFF201029)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'flash_im playground',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '这里用于演练、试验和学习，不进入正式产品打包入口。',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                _PlaygroundEntryCard(
                  title: 'conversation',
                  description: '一个可配置 IP 的 Dio 网络请求单元，用来拉取会话列表。',
                  icon: Icons.cloud_sync_outlined,
                  buttonLabel: '打开 conversation',
                  buttonColor: const Color(0xFF7EE787),
                  buttonForegroundColor: const Color(0xFF06230B),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ConversationPlaygroundPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                _PlaygroundEntryCard(
                  title: '烟花秀',
                  description: '点击后进入全屏烟花场景，轻触屏幕就会在落点炸开一束新的颜色。',
                  icon: Icons.auto_awesome,
                  buttonLabel: '打开烟花秀',
                  buttonColor: const Color(0xFFFF7A18),
                  buttonForegroundColor: const Color(0xFF130B03),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FireworksShowPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaygroundEntryCard extends StatelessWidget {
  const _PlaygroundEntryCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonLabel,
    required this.buttonColor,
    required this.buttonForegroundColor,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final String buttonLabel;
  final Color buttonColor;
  final Color buttonForegroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x141D31CC),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF2A3456)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: buttonForegroundColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
