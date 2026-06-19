import 'package:flash_auth/flash_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/app_router.dart';

void main() {
  testWidgets('password mode submits password login branch', (tester) async {
    final repository = _FakeAuthRepository();
    AppSession? capturedSession;

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: repository,
        child: MaterialApp(
          home: LoginPage(
            homeRouteName: AppRoutes.home,
            onLoginSuccess: (session) async {
              capturedSession = session;
            },
          ),
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
    );

    await tester.tap(find.text('密码登录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    await tester.enterText(find.byType(TextField).at(1), 'rainy123');
    await tester.pump();

    final loginButton = find.widgetWithText(FilledButton, '登录');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(repository.passwordLoginCount, 1);
    expect(repository.lastIdentifier, '13800138000');
    expect(repository.lastPassword, 'rainy123');
    expect(capturedSession?.token, 'jwt-token');
    expect(find.text('home'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  int passwordLoginCount = 0;
  String? lastIdentifier;
  String? lastPassword;

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
  Future<String> sendSmsCode(String phone) async => '654321';
}
