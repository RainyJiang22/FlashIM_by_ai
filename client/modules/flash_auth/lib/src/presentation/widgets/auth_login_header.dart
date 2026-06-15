import 'package:flutter/material.dart';

class AuthLoginHeader extends StatelessWidget {
  const AuthLoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Image.asset('assets/branding/flash_im_logo.png', width: 84),
        const SizedBox(height: 12),
        Text(
          'Flash IM',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C4EFF),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '轻量、干净、直接的体验',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF6A7B92),
          ),
        ),
      ],
    );
  }
}
