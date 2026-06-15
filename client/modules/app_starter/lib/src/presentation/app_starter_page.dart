import 'dart:async';

import 'package:flash_auth/flash_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/app_starter_options.dart';
import '../domain/app_starter_stage.dart';
import 'widgets/starter_brand_panel.dart';
import 'widgets/starter_failure_panel.dart';

class AppStarterPage extends StatefulWidget {
  const AppStarterPage({super.key, required this.options});

  final AppStarterOptions options;

  @override
  State<AppStarterPage> createState() => _AppStarterPageState();
}

class _AppStarterPageState extends State<AppStarterPage> {
  AppStarterStage _stage = AppStarterStage.idle;
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
    _loginRouteTimer = Timer(widget.options.unauthenticatedDelay, () {
      if (!mounted) {
        return;
      }
      _goToRoute(widget.options.routes.loginRouteName);
    });
  }

  void _retryRestore() {
    context.read<AppSessionCubit>().restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppSessionCubit, AppSessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        switch (state.status) {
          case AuthStatus.initial:
            break;
          case AuthStatus.restoring:
            _loginRouteTimer?.cancel();
            setState(() {
              _stage = AppStarterStage.loading;
              _errorMessage = null;
            });
            break;
          case AuthStatus.authenticated:
            _loginRouteTimer?.cancel();
            setState(() {
              _stage = AppStarterStage.ready;
              _errorMessage = null;
            });
            _goToRoute(widget.options.routes.homeRouteName);
            break;
          case AuthStatus.unauthenticated:
            setState(() {
              _stage = AppStarterStage.ready;
              _errorMessage = null;
            });
            _scheduleLoginRoute();
            break;
          case AuthStatus.failure:
            _loginRouteTimer?.cancel();
            setState(() {
              _stage = AppStarterStage.failed;
              _errorMessage =
                  state.errorMessage ?? widget.options.failureMessage;
            });
            break;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F9),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: StarterBrandPanel(
                branding: widget.options.branding,
                stage: _stage,
              ),
            ),
          ),
        ),
        bottomSheet: _stage == AppStarterStage.failed
            ? StarterFailurePanel(
                message: _errorMessage ?? widget.options.failureMessage,
                retryLabel: widget.options.retryLabel,
                onRetry: _retryRestore,
              )
            : null,
      ),
    );
  }
}
