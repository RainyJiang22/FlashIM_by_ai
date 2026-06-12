import '../../../core/auth/auth_cache_store.dart';
import '../../../core/config/app_config.dart';
import 'launch_destination.dart';

class AppBootstrapSnapshot {
  const AppBootstrapSnapshot({
    required this.destination,
    required this.hasAuthSession,
    required this.config,
    this.session,
  });

  final LaunchDestination destination;
  final bool hasAuthSession;
  final LocalAppConfig config;
  final CachedAuthSession? session;
}
