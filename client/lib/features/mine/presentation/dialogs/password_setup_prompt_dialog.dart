import 'package:flutter/material.dart';

class PasswordSetupPromptDialog extends StatelessWidget {
  const PasswordSetupPromptDialog({
    super.key,
    required this.onSkip,
    required this.onSetNow,
  });

  final VoidCallback onSkip;
  final VoidCallback onSetNow;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置登录密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前账号还没有登录密码，建议现在补充，方便下次直接使用密码登录。',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: onSkip, child: const Text('稍后设置')),
        FilledButton(onPressed: onSetNow, child: const Text('立即设置')),
      ],
    );
  }
}
