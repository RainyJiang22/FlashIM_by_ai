import 'package:flutter/material.dart';

import '../../domain/app_starter_branding.dart';
import '../../domain/app_starter_stage.dart';

class StarterBrandPanel extends StatelessWidget {
  const StarterBrandPanel({
    super.key,
    required this.branding,
    required this.stage,
  });

  final AppStarterBranding branding;
  final AppStarterStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        branding.logo,
        const SizedBox(height: 20),
        Text(
          branding.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF1C4EFF),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          stage == AppStarterStage.loading
              ? branding.loadingSubtitle
              : branding.idleSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF667085),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
