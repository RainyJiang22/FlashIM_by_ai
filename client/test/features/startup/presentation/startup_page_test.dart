import 'package:app_starter/app_starter.dart';
import 'package:flash_auth/flash_auth.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/app_router.dart';

void main() {
  testWidgets('startup page routes to login page', (tester) async {
    final authRepository = _FakeAuthRepository();
    final sessionRepository = _FakeSessionRepository();
    final cubit = SessionCubit(repository: sessionRepository);

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: authRepository,
        child: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: onGenerateAppRoute,
            home: _buildStarterPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('startup page routes to home shell', (tester) async {
    final authRepository = _FakeAuthRepository();
    final sessionRepository = _FakeSessionRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
    );
    final cubit = SessionCubit(repository: sessionRepository);

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: authRepository,
        child: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: onGenerateAppRoute,
            home: _buildStarterPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('消息'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('startup page shows retry on restore failure', (tester) async {
    final authRepository = _FakeAuthRepository();
    final sessionRepository = _ThrowingThenSuccessSessionRepository();
    final cubit = SessionCubit(repository: sessionRepository);

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: authRepository,
        child: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: onGenerateAppRoute,
            home: _buildStarterPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('启动失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    await cubit.close();
  });
}

AppStarterPage _buildStarterPage() {
  return AppStarterPage(
    options: AppStarterOptions(
      routes: const AppStarterRoutes(
        loginRouteName: AppRoutes.login,
        homeRouteName: AppRoutes.home,
      ),
      branding: const AppStarterBranding(
        logo: SizedBox(width: 132, height: 132),
        title: 'Flash IM',
        idleSubtitle: '轻量即时通讯',
        loadingSubtitle: '正在恢复登录状态...',
      ),
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    return const AppSession(
      token: 'jwt-token',
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
      token: 'jwt-token',
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
      avatar: 'identicon:startup-seed',
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

class _ThrowingThenSuccessSessionRepository extends _FakeSessionRepository {
  bool _didThrow = false;

  @override
  Future<CachedAuthSession?> readCachedSession() async {
    if (!_didThrow) {
      _didThrow = true;
      throw const FormatException('corrupted cache');
    }
    return null;
  }
}
