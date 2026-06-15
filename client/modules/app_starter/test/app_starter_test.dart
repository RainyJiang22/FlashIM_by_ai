import 'package:app_starter/app_starter.dart';
import 'package:flash_auth/flash_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports starter models', () {
    const routes = AppStarterRoutes(
      loginRouteName: '/login',
      homeRouteName: '/home',
    );
    const options = AppStarterOptions(
      routes: routes,
      branding: AppStarterBranding(
        logo: SizedBox(width: 100, height: 100),
        title: 'Flash IM',
        idleSubtitle: '轻量即时通讯',
        loadingSubtitle: '正在恢复登录状态...',
      ),
    );

    expect(AppStarterStage.values, hasLength(4));
    expect(options.routes.homeRouteName, '/home');
  });

  testWidgets('routes to login when session restore reports unauthenticated', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final cubit = AppSessionCubit(repository: repository);

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: repository,
        child: BlocProvider<AppSessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            routes: {
              '/login': (_) => const Scaffold(body: Text('login')),
              '/home': (_) => const Scaffold(body: Text('home')),
            },
            home: AppStarterPage(
              options: const AppStarterOptions(
                routes: AppStarterRoutes(
                  loginRouteName: '/login',
                  homeRouteName: '/home',
                ),
                branding: AppStarterBranding(
                  logo: SizedBox(width: 100, height: 100),
                  title: 'Flash IM',
                  idleSubtitle: '轻量即时通讯',
                  loadingSubtitle: '正在恢复登录状态...',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    await cubit.close();
  });
}

class _FakeAuthRepository implements AuthRepository {
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
  Future<CachedAuthSession?> readCachedSession() async => null;

  @override
  Future<void> setPassword({required String newPassword}) async {}

  @override
  Future<String> sendSmsCode(String phone) async => '654321';
}
