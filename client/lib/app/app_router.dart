import 'package:app_starter/app_starter.dart';
import 'package:flash_auth/flash_auth.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/home/presentation/main_shell_page.dart';

abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const home = '/home';
  static const editProfile = '/mine/profile/edit';
  static const setPassword = '/mine/password/set';
  static const changePassword = '/mine/password/change';
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
        builder: (context) => LoginPage(
          homeRouteName: AppRoutes.home,
          onLoginSuccess: context.read<SessionCubit>().completeLogin,
        ),
        settings: settings,
      );
    case AppRoutes.home:
      return MaterialPageRoute<void>(
        builder: (_) => const MainShellPage(),
        settings: settings,
      );
    case AppRoutes.editProfile:
      return MaterialPageRoute<void>(
        builder: (_) => const EditProfilePage(),
        settings: settings,
      );
    case AppRoutes.setPassword:
      return MaterialPageRoute<void>(
        builder: (_) => const SetPasswordPage(),
        settings: settings,
      );
    case AppRoutes.changePassword:
      return MaterialPageRoute<void>(
        builder: (_) => const ChangePasswordPage(),
        settings: settings,
      );
    default:
      return null;
  }
}
