import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/app_router.dart';
import 'package:flash_im/core/auth/auth_cache_store.dart';
import 'package:flash_im/features/auth/cubit/app_session_cubit.dart';
import 'package:flash_im/features/auth/data/auth_repository.dart';
import 'package:flash_im/features/auth/domain/app_session.dart';
import 'package:flash_im/features/auth/domain/auth_profile.dart';
import 'package:flash_im/features/startup/presentation/startup_page.dart';

void main() {
  testWidgets('startup page routes to login page', (tester) async {
    final repository = _FakeAuthRepository();
    final cubit = AppSessionCubit(repository: repository);

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: repository,
        child: BlocProvider<AppSessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: onGenerateAppRoute,
            home: const StartupPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('进入轻聊'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('startup page routes to home shell', (tester) async {
    final repository = _FakeAuthRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
    );
    final cubit = AppSessionCubit(repository: repository);

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: repository,
        child: BlocProvider<AppSessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: onGenerateAppRoute,
            home: const StartupPage(),
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
    final repository = _ThrowingThenSuccessAuthRepository();
    final cubit = AppSessionCubit(repository: repository);

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: repository,
        child: BlocProvider<AppSessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: onGenerateAppRoute,
            home: const StartupPage(),
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

    expect(find.text('进入轻聊'), findsOneWidget);
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

class _ThrowingThenSuccessAuthRepository extends _FakeAuthRepository {
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
