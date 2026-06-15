import '../storage/auth_cache_store.dart';
import '../domain/app_session.dart';
import '../domain/auth_profile.dart';
import 'auth_api.dart';
import 'models/auth_profile_dto.dart';
import 'models/auth_session_dto.dart';

abstract interface class AuthRepository {
  Future<CachedAuthSession?> readCachedSession();

  Future<String> sendSmsCode(String phone);

  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  });

  Future<AppSession> loginWithSmsCode({
    required String phone,
    required String code,
  });

  Future<void> persistSession(AppSession session);

  Future<AuthProfile> fetchProfile();

  Future<void> setPassword({required String newPassword});

  Future<void> logout();
}

class DefaultAuthRepository implements AuthRepository {
  DefaultAuthRepository({
    required AuthApi api,
    required AuthCacheStore cacheStore,
  }) : _api = api,
       _cacheStore = cacheStore;

  final AuthApi _api;
  final AuthCacheStore _cacheStore;

  @override
  Future<AuthProfile> fetchProfile() async {
    final session = await _readRequiredSession();
    final dto = await _api.fetchProfile(token: session.token);
    return _mapProfile(dto);
  }

  @override
  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    final dto = await _api.loginWithPassword(
      identifier: identifier,
      password: password,
    );
    return _mapSession(dto);
  }

  @override
  Future<AppSession> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    final dto = await _api.loginWithSmsCode(phone: phone, code: code);
    return _mapSession(dto);
  }

  @override
  Future<void> logout() => _cacheStore.clear();

  @override
  Future<void> persistSession(AppSession session) {
    return _cacheStore.save(
      CachedAuthSession(token: session.token, accountId: session.accountId),
    );
  }

  @override
  Future<CachedAuthSession?> readCachedSession() => _cacheStore.read();

  @override
  Future<String> sendSmsCode(String phone) async {
    final dto = await _api.sendSmsCode(phone: phone);
    return dto.code;
  }

  @override
  Future<void> setPassword({required String newPassword}) async {
    final session = await _readRequiredSession();
    await _api.setPassword(token: session.token, newPassword: newPassword);
  }

  Future<CachedAuthSession> _readRequiredSession() async {
    final session = await _cacheStore.read();
    if (session == null || session.token.isEmpty) {
      throw const AuthMissingTokenException();
    }
    return session;
  }

  AuthProfile _mapProfile(AuthProfileDto dto) {
    return AuthProfile(
      accountId: dto.accountId,
      nickname: dto.nickname,
      avatarUrl: dto.avatar,
      phone: dto.phone,
      hasPassword: dto.hasPassword,
    );
  }

  AppSession _mapSession(AuthSessionDto dto) {
    return AppSession(
      token: dto.token,
      accountId: dto.accountId,
      passwordSetupRequired: dto.passwordSetupRequired,
    );
  }
}

class AuthMissingTokenException implements Exception {
  const AuthMissingTokenException();

  @override
  String toString() => 'AuthMissingTokenException: token not found.';
}
