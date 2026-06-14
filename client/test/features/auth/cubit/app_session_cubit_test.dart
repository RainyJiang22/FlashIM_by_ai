import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/core/auth/auth_cache_store.dart';
import 'package:flash_im/features/auth/cubit/app_session_cubit.dart';
import 'package:flash_im/features/auth/data/auth_repository.dart';
import 'package:flash_im/features/auth/domain/app_session.dart';
import 'package:flash_im/features/auth/domain/auth_profile.dart';
import 'package:flash_im/features/auth/domain/auth_status.dart';

void main() {
  test('restoreSession emits authenticated when cached token exists', () async {
    final repository = _FakeAuthRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
    );
    final cubit = AppSessionCubit(repository: repository);

    await cubit.restoreSession();

    expect(cubit.state.status, AuthStatus.authenticated);
    expect(cubit.state.session?.token, 'jwt-token');
    await cubit.close();
  });

  test(
    'completeLogin persists session and keeps password prompt flag',
    () async {
      final repository = _FakeAuthRepository();
      final cubit = AppSessionCubit(repository: repository);

      await cubit.completeLogin(
        const AppSession(
          token: 'jwt-token',
          accountId: 10001,
          passwordSetupRequired: true,
        ),
      );

      expect(repository.persistedSession?.token, 'jwt-token');
      expect(cubit.state.shouldPromptPasswordSetup, isTrue);
      await cubit.close();
    },
  );

  test('logout clears cache and emits unauthenticated', () async {
    final repository = _FakeAuthRepository();
    final cubit = AppSessionCubit(repository: repository);

    await cubit.logout();

    expect(repository.logoutCount, 1);
    expect(cubit.state.status, AuthStatus.unauthenticated);
    await cubit.close();
  });

  test('refreshProfile syncs profile into authenticated state', () async {
    final repository = _FakeAuthRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
      profile: const AuthProfile(
        accountId: 10001,
        nickname: 'Rainy',
        avatarUrl: 'https://picsum.photos/seed/rainy/120/120',
        phone: '13800138000',
        hasPassword: false,
      ),
    );
    final cubit = AppSessionCubit(repository: repository);

    await cubit.restoreSession();
    await cubit.refreshProfile();

    expect(cubit.state.profile?.nickname, 'Rainy');
    expect(cubit.state.shouldPromptPasswordSetup, isTrue);
    await cubit.close();
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.cachedSession, this.profile});

  final CachedAuthSession? cachedSession;
  final AuthProfile? profile;
  AppSession? persistedSession;
  int logoutCount = 0;

  @override
  Future<AuthProfile> fetchProfile() async {
    return profile ??
        const AuthProfile(
          accountId: 10001,
          nickname: 'Rainy',
          avatarUrl: 'https://picsum.photos/seed/rainy/120/120',
          phone: '13800138000',
          hasPassword: true,
        );
  }

  @override
  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    return const AppSession(
      token: 'password-token',
      accountId: 10001,
      passwordSetupRequired: false,
    );
  }

  @override
  Future<AppSession> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    return const AppSession(
      token: 'sms-token',
      accountId: 10001,
      passwordSetupRequired: false,
    );
  }

  @override
  Future<void> logout() async {
    logoutCount += 1;
  }

  @override
  Future<void> persistSession(AppSession session) async {
    persistedSession = session;
  }

  @override
  Future<CachedAuthSession?> readCachedSession() async => cachedSession;

  @override
  Future<void> setPassword({required String newPassword}) async {}

  @override
  Future<String> sendSmsCode(String phone) async => '654321';
}
