import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/core/auth/auth_cache_store.dart';
import 'package:flash_im/features/auth/data/auth_api.dart';
import 'package:flash_im/features/auth/data/auth_repository.dart';
import 'package:flash_im/features/auth/data/models/auth_profile_dto.dart';
import 'package:flash_im/features/auth/data/models/auth_session_dto.dart';
import 'package:flash_im/features/auth/data/models/password_setup_result_dto.dart';
import 'package:flash_im/features/auth/data/models/sms_code_dto.dart';

void main() {
  test(
    'repository maps login result and persists session explicitly',
    () async {
      final api = _FakeAuthApi();
      final cacheStore = _InMemoryAuthCacheStore();
      final repository = DefaultAuthRepository(
        api: api,
        cacheStore: cacheStore,
      );

      final session = await repository.loginWithSmsCode(
        phone: '13800138000',
        code: '654321',
      );
      await repository.persistSession(session);
      final profile = await repository.fetchProfile();

      expect(session.token, 'jwt-token');
      expect(session.accountId, 10001);
      expect(await cacheStore.read(), isNotNull);
      expect(api.lastProfileToken, 'jwt-token');
      expect(profile.hasPassword, isFalse);
    },
  );

  test('repository reads password login and logout clears cache', () async {
    final api = _FakeAuthApi();
    final cacheStore = _InMemoryAuthCacheStore();
    final repository = DefaultAuthRepository(api: api, cacheStore: cacheStore);

    final session = await repository.loginWithPassword(
      identifier: '13800138000',
      password: 'rainy123',
    );
    await repository.persistSession(session);
    await repository.logout();

    expect(api.lastIdentifier, '13800138000');
    expect(api.lastPassword, 'rainy123');
    expect(await cacheStore.read(), isNull);
  });

  test('repository throws when profile requested without token', () async {
    final repository = DefaultAuthRepository(
      api: _FakeAuthApi(),
      cacheStore: _InMemoryAuthCacheStore(),
    );

    expect(repository.fetchProfile, throwsA(isA<AuthMissingTokenException>()));
  });
}

class _FakeAuthApi implements AuthApi {
  String? lastIdentifier;
  String? lastPassword;
  String? lastProfileToken;

  @override
  Future<AuthProfileDto> fetchProfile({required String token}) async {
    lastProfileToken = token;
    return const AuthProfileDto(
      accountId: 10001,
      nickname: 'Rainy',
      avatar: 'https://picsum.photos/seed/rainy/120/120',
      phone: '13800138000',
      hasPassword: false,
    );
  }

  @override
  Future<AuthSessionDto> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    lastIdentifier = identifier;
    lastPassword = password;
    return const AuthSessionDto(
      token: 'password-token',
      accountId: 10001,
      passwordSetupRequired: false,
    );
  }

  @override
  Future<AuthSessionDto> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    return const AuthSessionDto(
      token: 'jwt-token',
      accountId: 10001,
      passwordSetupRequired: true,
    );
  }

  @override
  Future<SmsCodeDto> sendSmsCode({required String phone}) async {
    return SmsCodeDto(phone: phone, code: '654321');
  }

  @override
  Future<PasswordSetupResultDto> setPassword({
    required String token,
    required String newPassword,
  }) async {
    return const PasswordSetupResultDto(
      passwordSetupRequired: false,
      updatedAt: '2026-06-14T10:30:00Z',
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
