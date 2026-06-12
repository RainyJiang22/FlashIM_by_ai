import '../../../core/auth/auth_cache_store.dart';
import '../../../core/config/local_config_store.dart';
import '../domain/app_bootstrap_snapshot.dart';
import '../domain/launch_destination.dart';

abstract interface class StartupCoordinator {
  Future<AppBootstrapSnapshot> bootstrap();
}

class DefaultStartupCoordinator implements StartupCoordinator {
  const DefaultStartupCoordinator({
    required LocalConfigStore configStore,
    required AuthCacheStore authCacheStore,
  }) : _configStore = configStore,
       _authCacheStore = authCacheStore;

  final LocalConfigStore _configStore;
  final AuthCacheStore _authCacheStore;

  @override
  Future<AppBootstrapSnapshot> bootstrap() async {
    final config = await _configStore.load();

    CachedAuthSession? session;
    try {
      session = await _authCacheStore.read();
    } catch (_) {
      await _authCacheStore.clear();
      session = null;
    }

    final hasAuthSession = session != null;
    return AppBootstrapSnapshot(
      destination: hasAuthSession
          ? LaunchDestination.home
          : LaunchDestination.login,
      hasAuthSession: hasAuthSession,
      config: config,
      session: session,
    );
  }
}
