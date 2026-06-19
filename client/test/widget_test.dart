import 'package:flash_auth/flash_auth.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/flash_im_app.dart';
import 'package:flash_im/core/config/app_config.dart';

void main() {
  testWidgets('main app restores cached session into home shell', (
    WidgetTester tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final sessionRepository = _FakeSessionRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
    );
    final cubit = SessionCubit(repository: sessionRepository);

    await tester.pumpWidget(
      FlashImApp(
        appConfig: const LocalAppConfig(
          appName: 'Flash IM',
          apiBaseUrl: 'http://127.0.0.1:9600',
          enableDebugTools: false,
        ),
        authRepository: authRepository,
        sessionRepository: sessionRepository,
        sessionCubit: cubit,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('消息'), findsOneWidget);
    await cubit.close();
  });
}

class _FakeAuthRepository implements AuthRepository {
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
  Future<String> sendSmsCode(String phone) async => '654321';
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({this.cachedSession});

  final CachedAuthSession? cachedSession;

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<User> fetchProfile() async {
    return const User(
      userId: 10001,
      nickname: 'Rainy',
      avatar: 'identicon:widget-test',
      phone: '13800138000',
      signature: '',
      hasPassword: true,
    );
  }

  @override
  Future<void> persistSession(AppSession session) async {}

  @override
  Future<CachedAuthSession?> readCachedSession() async => cachedSession;

  @override
  Future<void> setPassword({required String newPassword}) async {}

  @override
  Future<User> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    return await fetchProfile();
  }
}
