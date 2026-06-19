import 'package:flash_auth/flash_auth.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restoreSession emits authenticated when cached token exists', () async {
    final repository = _FakeSessionRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
    );
    final cubit = SessionCubit(repository: repository);

    await cubit.restoreSession();

    expect(cubit.state.status, SessionStatus.authenticated);
    expect(cubit.state.session?.token, 'jwt-token');
    await cubit.close();
  });

  test('completeLogin persists session and keeps password prompt flag', () async {
    final repository = _FakeSessionRepository();
    final cubit = SessionCubit(repository: repository);

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
  });

  test('refreshProfile syncs user into authenticated state', () async {
    final repository = _FakeSessionRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
      user: const User(
        userId: 10001,
        nickname: 'Rainy',
        avatar: 'identicon:seed-1',
        phone: '13800138000',
        signature: 'hello',
        hasPassword: false,
      ),
    );
    final cubit = SessionCubit(repository: repository);

    await cubit.restoreSession();
    await cubit.refreshProfile();

    expect(cubit.state.user?.nickname, 'Rainy');
    expect(cubit.state.shouldPromptPasswordSetup, isTrue);
    await cubit.close();
  });

  test('setPassword updates prompt state and password flag', () async {
    final repository = _FakeSessionRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
      user: const User(
        userId: 10001,
        nickname: 'Rainy',
        avatar: 'identicon:seed-1',
        phone: '13800138000',
        signature: '',
        hasPassword: false,
      ),
    );
    final cubit = SessionCubit(repository: repository);

    await cubit.restoreSession();
    await cubit.refreshProfile();
    await cubit.setPassword(newPassword: 'rainy123');

    expect(repository.lastSetPassword, 'rainy123');
    expect(cubit.state.user?.hasPassword, isTrue);
    expect(cubit.state.shouldPromptPasswordSetup, isFalse);
    await cubit.close();
  });
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({this.cachedSession, this.user});

  final CachedAuthSession? cachedSession;
  User? user;
  AppSession? persistedSession;
  String? lastSetPassword;

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<User> fetchProfile() async {
    return user ??
        const User(
          userId: 10001,
          nickname: 'Rainy',
          avatar: 'identicon:seed-default',
          phone: '13800138000',
          signature: '',
          hasPassword: true,
        );
  }

  @override
  Future<void> persistSession(AppSession session) async {
    persistedSession = session;
  }

  @override
  Future<CachedAuthSession?> readCachedSession() async => cachedSession;

  @override
  Future<void> setPassword({required String newPassword}) async {
    lastSetPassword = newPassword;
    user = (user ??
            const User(
              userId: 10001,
              nickname: 'Rainy',
              avatar: 'identicon:seed-default',
              phone: '13800138000',
              signature: '',
              hasPassword: false,
            ))
        .copyWith(hasPassword: true);
  }

  @override
  Future<User> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    user = (await fetchProfile()).copyWith(
      nickname: nickname,
      signature: signature,
      avatar: avatar,
    );
    return user!;
  }
}
