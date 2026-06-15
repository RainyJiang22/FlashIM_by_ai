import 'app_starter_branding.dart';
import 'app_starter_routes.dart';

class AppStarterOptions {
  const AppStarterOptions({
    required this.routes,
    required this.branding,
    this.unauthenticatedDelay = const Duration(seconds: 3),
    this.failureMessage = '启动失败，请重试',
    this.retryLabel = '重试',
  });

  final AppStarterRoutes routes;
  final AppStarterBranding branding;
  final Duration unauthenticatedDelay;
  final String failureMessage;
  final String retryLabel;
}
