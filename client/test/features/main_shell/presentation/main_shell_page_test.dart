import 'package:flash_auth/flash_auth.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/features/home/presentation/main_shell_page.dart';

void main() {
  testWidgets('main shell shows password setup prompt and switches tabs', (
    tester,
  ) async {
    final repository = _FakeSessionRepository();
    final cubit = SessionCubit(repository: repository);

    await tester.pumpWidget(
      BlocProvider<SessionCubit>.value(
        value: cubit,
        child: const MaterialApp(home: MainShellPage()),
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
      avatar: 'identicon:seed-main-shell',
      phone: '13800138000',
      signature: '',
      hasPassword: false,
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
