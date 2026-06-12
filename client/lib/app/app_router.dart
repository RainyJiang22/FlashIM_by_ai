import 'package:flutter/material.dart';

import '../features/startup/data/startup_coordinator_impl.dart';
import '../features/startup/presentation/home_placeholder_page.dart';
import '../features/startup/presentation/login_placeholder_page.dart';
import '../features/startup/presentation/startup_page.dart';

abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const home = '/home';
}

Route<dynamic>? onGenerateAppRoute(
  RouteSettings settings, {
  StartupCoordinator? startupCoordinator,
}) {
  switch (settings.name) {
    case AppRoutes.startup:
      return MaterialPageRoute<void>(
        builder: (_) => StartupPage(coordinator: startupCoordinator),
        settings: settings,
      );
    case AppRoutes.login:
      return MaterialPageRoute<void>(
        builder: (_) => const LoginPlaceholderPage(),
        settings: settings,
      );
    case AppRoutes.home:
      return MaterialPageRoute<void>(
        builder: (_) => const HomePlaceholderPage(),
        settings: settings,
      );
    default:
      return null;
  }
}
