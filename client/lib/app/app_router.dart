import 'package:flutter/material.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/main_shell/presentation/main_shell_page.dart';
import '../features/startup/presentation/startup_page.dart';

abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const home = '/home';
}

Route<dynamic>? onGenerateAppRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.startup:
      return MaterialPageRoute<void>(
        builder: (_) => const StartupPage(),
        settings: settings,
      );
    case AppRoutes.login:
      return MaterialPageRoute<void>(
        builder: (_) => const LoginPage(),
        settings: settings,
      );
    case AppRoutes.home:
      return MaterialPageRoute<void>(
        builder: (_) => const MainShellPage(),
        settings: settings,
      );
    default:
      return null;
  }
}
