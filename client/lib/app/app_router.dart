import 'package:app_starter/app_starter.dart';
import 'package:flash_auth/flash_auth.dart';
import 'package:flutter/material.dart';

import '../features/home/presentation/main_shell_page.dart';

abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const home = '/home';
}

Route<dynamic>? onGenerateAppRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.startup:
      return MaterialPageRoute<void>(
        builder: (_) => AppStarterPage(
          options: AppStarterOptions(
            routes: const AppStarterRoutes(
              loginRouteName: AppRoutes.login,
              homeRouteName: AppRoutes.home,
            ),
            branding: AppStarterBranding(
              logo: Image.asset(
                'assets/branding/flash_im_logo_alpha.png',
                width: 132,
              ),
              title: 'Flash IM',
              idleSubtitle: '轻量即时通讯',
              loadingSubtitle: '正在恢复登录状态...',
            ),
          ),
        ),
        settings: settings,
      );
    case AppRoutes.login:
      return MaterialPageRoute<void>(
        builder: (_) => const LoginPage(homeRouteName: AppRoutes.home),
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
