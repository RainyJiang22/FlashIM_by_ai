import 'package:flash_auth/flash_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/features/home/presentation/main_shell_page.dart';

void main() {
  testWidgets('main shell shows password setup prompt and switches tabs', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final cubit = AppSessionCubit(repository: repository);

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: repository,
        child: BlocProvider<AppSessionCubit>.value(
          value: cubit,
          child: const MaterialApp(home: MainShellPage()),
        ),
      ),
    );

    await cubit.completeLogin(
      const AppSession(
        token: 'jwt-token',
        accountId: 10001,
        passwordSetupRequired: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置登录密码'), findsOneWidget);
    await tester.tap(find.text('稍后设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置登录密码'), findsNothing);

    await tester.tap(find.text('通讯录'));
    await tester.pumpAndSettle();
    expect(find.text('通讯录页暂未开放'), findsOneWidget);

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
      hasPassword: false,
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
  Future<CachedAuthSession?> readCachedSession() async => null;

  @override
  Future<void> setPassword({required String newPassword}) async {}

  @override
  Future<String> sendSmsCode(String phone) async => '654321';
}
