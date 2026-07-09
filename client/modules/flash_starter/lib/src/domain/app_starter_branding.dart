import 'package:flutter/widgets.dart';

class AppStarterBranding {
  const AppStarterBranding({
    required this.logo,
    required this.title,
    required this.idleSubtitle,
    required this.loadingSubtitle,
  });

  final Widget logo;
  final String title;
  final String idleSubtitle;
  final String loadingSubtitle;
}
