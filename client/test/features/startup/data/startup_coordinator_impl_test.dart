import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/core/auth/auth_cache_store.dart';
import 'package:flash_im/core/config/app_config.dart';
import 'package:flash_im/core/config/local_config_store.dart';
import 'package:flash_im/features/startup/data/startup_coordinator_impl.dart';
import 'package:flash_im/features/startup/domain/launch_destination.dart';

void main() {
  test('bootstrap goes to login when no cached session', () async {
    final coordinator = DefaultStartupCoordinator(
      configStore: _FakeLocalConfigStore(),
      authCacheStore: _FakeAuthCacheStore(session: null),
    );

    final snapshot = await coordinator.bootstrap();

    expect(snapshot.destination, LaunchDestination.login);
    expect(snapshot.hasAuthSession, isFalse);
  });

  test('bootstrap goes to home when token exists', () async {
    final coordinator = DefaultStartupCoordinator(
      configStore: _FakeLocalConfigStore(),
      authCacheStore: const _FakeAuthCacheStore(
        session: CachedAuthSession(token: 'jwt-token', accountId: 10001),
      ),
    );

    final snapshot = await coordinator.bootstrap();

    expect(snapshot.destination, LaunchDestination.home);
    expect(snapshot.hasAuthSession, isTrue);
    expect(snapshot.session?.token, 'jwt-token');
  });

  test('bootstrap clears corrupted cache and falls back to login', () async {
    final cacheStore = _ThrowingAuthCacheStore();
    final coordinator = DefaultStartupCoordinator(
      configStore: _FakeLocalConfigStore(),
      authCacheStore: cacheStore,
    );

    final snapshot = await coordinator.bootstrap();

    expect(snapshot.destination, LaunchDestination.login);
    expect(snapshot.hasAuthSession, isFalse);
    expect(cacheStore.cleared, isTrue);
  });
}

class _FakeLocalConfigStore implements LocalConfigStore {
  @override
  Future<LocalAppConfig> load() async {
    return const LocalAppConfig(
      appName: 'Flash IM',
      apiBaseUrl: 'http://127.0.0.1:9600',
      enableDebugTools: false,
    );
  }
}

class _FakeAuthCacheStore implements AuthCacheStore {
  const _FakeAuthCacheStore({required this.session});

  final CachedAuthSession? session;

  @override
  Future<void> clear() async {}

  @override
  Future<CachedAuthSession?> read() async => session;

  @override
  Future<void> save(CachedAuthSession session) async {}
}

class _ThrowingAuthCacheStore implements AuthCacheStore {
  bool cleared = false;

  @override
  Future<void> clear() async {
    cleared = true;
  }

  @override
  Future<CachedAuthSession?> read() async {
    throw const FormatException('corrupted auth cache');
  }

  @override
  Future<void> save(CachedAuthSession session) async {}
}
