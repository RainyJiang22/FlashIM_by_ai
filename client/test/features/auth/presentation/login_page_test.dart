import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/app_router.dart';
import 'package:flash_im/core/auth/auth_cache_store.dart';
import 'package:flash_im/features/auth/cubit/app_session_cubit.dart';
import 'package:flash_im/features/auth/data/auth_repository.dart';
import 'package:flash_im/features/auth/domain/app_session.dart';
import 'package:flash_im/features/auth/domain/auth_profile.dart';
import 'package:flash_im/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('password mode submits password login branch', (tester) async {
    final repository = _FakeAuthRepository();
    final cubit = AppSessionCubit(repository: repository);

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: repository,
        child: BlocProvider<AppSessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: const LoginPage(),
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.home) {
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('home')),
                );
              }
              return null;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('密码登录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    await tester.enterText(find.byType(TextField).at(1), 'rainy123');
    await tester.pump();
    await tester.ensureVisible(find.text('进入轻聊'));
    await tester.tap(find.text('进入轻聊'));
    await tester.pumpAndSettle();

    expect(repository.passwordLoginCount, 1);
    expect(repository.lastIdentifier, '13800138000');
    expect(repository.lastPassword, 'rainy123');
    expect(find.text('home'), findsOneWidget);
    await cubit.close();
  });
}

class _FakeAuthRepository implements AuthRepository {
  int passwordLoginCount = 0;
  String? lastIdentifier;
  String? lastPassword;

  @override
  Future<AuthProfile> fetchProfile() async {
    return const AuthProfile(
      accountId: 10001,
      nickname: 'Rainy',
      avatarUrl: 'https://picsum.photos/seed/rainy/120/120',
      phone: '13800138000',
      hasPassword: false,
    );
  }

  @override
  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    passwordLoginCount += 1;
    lastIdentifier = identifier;
    lastPassword = password;
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
  Future<CachedAuthSession?> readCachedSession() async => null;

  @override
  Future<void> setPassword({required String newPassword}) async {}

  @override
  Future<String> sendSmsCode(String phone) async => '654321';
}
