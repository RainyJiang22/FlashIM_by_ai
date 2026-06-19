import 'package:flash_auth/flash_auth.dart';

import 'session_api.dart';
import 'user.dart';

abstract interface class SessionRepository {
  Future<CachedAuthSession?> readCachedSession();

  Future<void> persistSession(AppSession session);

  Future<void> clearSession();

  Future<User> fetchProfile();

  Future<User> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  });

  Future<void> setPassword({required String newPassword});

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
}

class DefaultSessionRepository implements SessionRepository {
  DefaultSessionRepository({
    required SessionApi api,
    required AuthCacheStore cacheStore,
  }) : _api = api,
       _cacheStore = cacheStore;

  final SessionApi _api;
  final AuthCacheStore _cacheStore;

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final session = await _readRequiredSession();
    await _api.changePassword(
      token: session.token,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> clearSession() => _cacheStore.clear();

  @override
  Future<User> fetchProfile() async {
    final session = await _readRequiredSession();
    return _api.fetchProfile(token: session.token);
  }

  @override
  Future<void> persistSession(AppSession session) {
    return _cacheStore.save(
      CachedAuthSession(token: session.token, accountId: session.accountId),
    );
  }

  @override
  Future<CachedAuthSession?> readCachedSession() => _cacheStore.read();

  @override
  Future<void> setPassword({required String newPassword}) async {
    final session = await _readRequiredSession();
    await _api.setPassword(token: session.token, newPassword: newPassword);
  }

  @override
  Future<User> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    final session = await _readRequiredSession();
    return _api.updateProfile(
      token: session.token,
      nickname: nickname,
      signature: signature,
      avatar: avatar,
    );
  }

  Future<CachedAuthSession> _readRequiredSession() async {
    final session = await _cacheStore.read();
    if (session == null || session.token.isEmpty) {
      throw const SessionMissingTokenException();
    }
    return session;
  }
}

class SessionMissingTokenException implements Exception {
  const SessionMissingTokenException();

  @override
  String toString() => 'SessionMissingTokenException: token not found.';
}
