import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/playground/demos/auth/data/auth_repository.dart';
import 'package:flash_im/playground/demos/auth/domain/auth_profile.dart';
import 'package:flash_im/playground/demos/auth/domain/auth_session.dart';
import 'package:flash_im/playground/demos/auth/domain/sms_code_info.dart';
import 'package:flash_im/playground/demos/auth/presentation/auth_playground_page.dart';

void main() {
  testWidgets('password mode submits password login branch', (tester) async {
    final repository = _FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(home: AuthPlaygroundPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('密码登录'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'alice123');
    await tester.ensureVisible(find.text('登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录'));
    await tester.pump();

    expect(repository.passwordLoginCount, 1);
    expect(repository.lastAccount, 'alice');
    expect(repository.lastPassword, 'alice123');
    expect(repository.smsLoginCount, 0);
  });
}

class _FakeAuthRepository implements AuthRepository {
  String? _token;
  int passwordLoginCount = 0;
  int smsLoginCount = 0;
  String? lastAccount;
  String? lastPassword;

  @override
  Future<AuthProfile> fetchProfile() async {
    return const AuthProfile(
      userId: 1002,
      nickname: 'Alice',
      avatarUrl: 'https://picsum.photos/seed/test/120/120',
      phone: '13800138002',
    );
  }

  @override
  Future<AuthSession> loginWithPassword({
    required String account,
    required String password,
  }) async {
    passwordLoginCount += 1;
    lastAccount = account;
    lastPassword = password;
    _token = 'password-token';
    return const AuthSession(token: 'password-token', userId: 1002);
  }

  @override
  Future<AuthSession> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    smsLoginCount += 1;
    _token = 'sms-token';
    return const AuthSession(token: 'sms-token', userId: 7);
  }

  @override
  Future<void> logout() async {
    _token = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<SmsCodeInfo> sendSmsCode(String phone) async {
    return const SmsCodeInfo(phone: '13800138000', code: '654321');
  }
}
