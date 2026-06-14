import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import '../../../app/app_router.dart';
import '../../auth/cubit/app_session_cubit.dart';
import '../../auth/domain/auth_status.dart';
import '../domain/startup_stage.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  static const _loginDelay = Duration(seconds: 3);

  StartupStage _stage = StartupStage.idle;
  String? _errorMessage;
  Timer? _loginRouteTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppSessionCubit>().restoreSession();
    });
  }

  @override
  void dispose() {
    _loginRouteTimer?.cancel();
    super.dispose();
  }

  void _goToRoute(String routeName) {
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  void _scheduleLoginRoute() {
    _loginRouteTimer?.cancel();
    _loginRouteTimer = Timer(_loginDelay, () {
      if (!mounted) {
        return;
      }
      _goToRoute(AppRoutes.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const appBackgroundColor = Color(0xFFF6F7F9);

    return BlocListener<AppSessionCubit, AppSessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        switch (state.status) {
          case AuthStatus.restoring:
            setState(() {
              _stage = StartupStage.loading;
              _errorMessage = null;
            });
          case AuthStatus.authenticated:
            _loginRouteTimer?.cancel();
            setState(() {
              _stage = StartupStage.ready;
            });
            _goToRoute(AppRoutes.home);
          case AuthStatus.unauthenticated:
            setState(() {
              _stage = StartupStage.ready;
            });
            _scheduleLoginRoute();
          case AuthStatus.failure:
            _loginRouteTimer?.cancel();
            setState(() {
              _stage = StartupStage.failed;
              _errorMessage = state.errorMessage ?? '启动失败，请重试';
            });
          case AuthStatus.initial:
            break;
        }
      },
      child: Scaffold(
        backgroundColor: appBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/branding/flash_im_logo_alpha.png', width: 132),
                  const SizedBox(height: 20),
                  Text(
                    'Flash IM',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF1C4EFF),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _stage == StartupStage.loading ? '正在恢复登录状态...' : '轻量即时通讯',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomSheet: _stage == StartupStage.failed
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage ?? '启动失败，请重试',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFB42318),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        context.read<AppSessionCubit>().restoreSession();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}
