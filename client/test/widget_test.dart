import 'package:flash_auth/flash_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/flash_im_app.dart';
import 'package:flash_im/core/config/app_config.dart';

void main() {
  testWidgets('main app restores cached session into home shell', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAuthRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
    );
    final cubit = AppSessionCubit(repository: repository);

    await tester.pumpWidget(
      FlashImApp(
        appConfig: const LocalAppConfig(
          appName: 'Flash IM',
          apiBaseUrl: 'http://127.0.0.1:9600',
          enableDebugTools: false,
        ),
        authRepository: repository,
        appSessionCubit: cubit,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('消息'), findsOneWidget);
    await cubit.close();
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.cachedSession});

  final CachedAuthSession? cachedSession;

  @override
  Future<AuthProfile> fetchProfile() async {
    return const AuthProfile(
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
  Future<void> logout() async {}

  @override
  Future<void> persistSession(AppSession session) async {}

  @override
  Future<CachedAuthSession?> readCachedSession() async => cachedSession;

  @override
  Future<void> setPassword({required String newPassword}) async {}

  @override
  Future<String> sendSmsCode(String phone) async => '654321';
}
