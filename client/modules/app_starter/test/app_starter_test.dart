import 'package:app_starter/app_starter.dart';
import 'package:flash_auth/flash_auth.dart';
import 'package:flash_session/flash_session.dart';
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
    final cubit = SessionCubit(repository: _FakeSessionRepository());

    await tester.pumpWidget(
      BlocProvider<SessionCubit>.value(
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
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    await cubit.close();
  });
}

class _FakeSessionRepository implements SessionRepository {
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
      avatar: 'identicon:app-starter',
      phone: '13800138000',
      signature: '',
      hasPassword: true,
    );
  }

  @override
  Future<void> persistSession(AppSession session) async {}

  @override
  Future<CachedAuthSession?> readCachedSession() async => null;

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
