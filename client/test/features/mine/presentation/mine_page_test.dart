import 'package:flash_auth/flash_auth.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/app_router.dart';
import 'package:flash_im/features/mine/presentation/mine_page.dart';

void main() {
  testWidgets('mine page shows user card and routes to password setup', (
    tester,
  ) async {
    final repository = _FakeSessionRepository(
      user: const User(
        userId: 10001,
        nickname: 'Rainy',
        avatar: 'identicon:mine-page',
        phone: '13800138000',
        signature: '你好',
        hasPassword: false,
      ),
    );
    final cubit = SessionCubit(repository: repository);
    await cubit.completeLogin(
      const AppSession(
        token: 'jwt-token',
        accountId: 10001,
        passwordSetupRequired: false,
      ),
    );

    await tester.pumpWidget(
      BlocProvider<SessionCubit>.value(
        value: cubit,
        child: MaterialApp(
          routes: {
            AppRoutes.setPassword: (_) =>
                const Scaffold(body: Text('set-password')),
          },
          home: const MinePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Rainy'), findsOneWidget);
    expect(find.text('首次设置'), findsOneWidget);

    await tester.tap(find.text('首次设置'));
    await tester.pumpAndSettle();

    expect(find.text('set-password'), findsOneWidget);
    await cubit.close();
  });
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({required this.user});

  User user;

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<User> fetchProfile() async => user;

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
    user = user.copyWith(
      nickname: nickname,
      signature: signature,
      avatar: avatar,
    );
    return user;
  }
}
