import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/app_starter_options.dart';
import '../domain/app_starter_stage.dart';
import '../domain/app_starter_state.dart';
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
  StreamSubscription<AppStarterState>? _starterStateSubscription;

  @override
  void initState() {
    super.initState();
    _starterStateSubscription = widget.options.controller.stream.listen(
      _handleStarterState,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.options.controller.restore();
    });
  }

  @override
  void dispose() {
    _starterStateSubscription?.cancel();
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
    widget.options.controller.restore();
  }

  void _handleStarterState(AppStarterState state) {
    switch (state.status) {
      case AppStarterStatus.initial:
        break;
      case AppStarterStatus.restoring:
        _loginRouteTimer?.cancel();
        setState(() {
          _stage = AppStarterStage.loading;
          _errorMessage = null;
        });
        break;
      case AppStarterStatus.authenticated:
        _loginRouteTimer?.cancel();
        setState(() {
          _stage = AppStarterStage.ready;
          _errorMessage = null;
        });
        _goToRoute(widget.options.routes.homeRouteName);
        break;
      case AppStarterStatus.unauthenticated:
        setState(() {
          _stage = AppStarterStage.ready;
          _errorMessage = null;
        });
        _scheduleLoginRoute();
        break;
      case AppStarterStatus.failure:
        _loginRouteTimer?.cancel();
        setState(() {
          _stage = AppStarterStage.failed;
          _errorMessage = state.errorMessage ?? widget.options.failureMessage;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
