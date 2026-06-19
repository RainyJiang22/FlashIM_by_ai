import 'package:flash_auth/flash_auth.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository maps profile update and password routes', () async {
    final api = _FakeSessionApi();
    final cacheStore = _InMemoryAuthCacheStore();
    await cacheStore.save(
      const CachedAuthSession(token: 'jwt-token', accountId: 10001),
    );
    final repository = DefaultSessionRepository(api: api, cacheStore: cacheStore);

    final profile = await repository.fetchProfile();
    final updated = await repository.updateProfile(signature: 'hello');
    await repository.setPassword(newPassword: 'rainy123');
    await repository.changePassword(
      oldPassword: 'old12345',
      newPassword: 'new12345',
    );

    expect(profile.userId, 10001);
    expect(updated.signature, 'hello');
    expect(api.lastToken, 'jwt-token');
    expect(api.lastSetPassword, 'rainy123');
    expect(api.lastOldPassword, 'old12345');
  });
}

class _FakeSessionApi implements SessionApi {
  String? lastToken;
  String? lastSetPassword;
  String? lastOldPassword;

  @override
  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    lastToken = token;
    lastOldPassword = oldPassword;
  }

  @override
  Future<User> fetchProfile({required String token}) async {
    lastToken = token;
    return const User(
      userId: 10001,
      nickname: 'Rainy',
      avatar: 'identicon:repo-test',
      phone: '13800138000',
      signature: '',
      hasPassword: false,
    );
  }

  @override
  Future<void> setPassword({
    required String token,
    required String newPassword,
  }) async {
    lastToken = token;
    lastSetPassword = newPassword;
  }

  @override
  Future<User> updateProfile({
    required String token,
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    lastToken = token;
    return User(
      userId: 10001,
      nickname: nickname ?? 'Rainy',
      avatar: avatar ?? 'identicon:repo-test',
      phone: '13800138000',
      signature: signature ?? '',
      hasPassword: false,
    );
  }
}

class _InMemoryAuthCacheStore implements AuthCacheStore {
  CachedAuthSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<CachedAuthSession?> read() async => _session;

  @override
  Future<void> save(CachedAuthSession session) async {
    _session = session;
  }
}
