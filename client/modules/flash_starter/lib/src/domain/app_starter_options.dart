import 'app_starter_branding.dart';
import 'app_starter_controller.dart';
import 'app_starter_routes.dart';

class AppStarterOptions {
  const AppStarterOptions({
    required this.routes,
    required this.branding,
    required this.controller,
    this.unauthenticatedDelay = const Duration(seconds: 3),
    this.failureMessage = '启动失败，请重试',
    this.retryLabel = '重试',
  });

  final AppStarterRoutes routes;
  final AppStarterBranding branding;
  final AppStarterController controller;
  final Duration unauthenticatedDelay;
  final String failureMessage;
  final String retryLabel;
}
