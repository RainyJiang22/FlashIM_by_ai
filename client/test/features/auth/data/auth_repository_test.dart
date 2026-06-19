import 'package:flash_auth/flash_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository maps sms login result', () async {
    final api = _FakeAuthApi();
    final repository = DefaultAuthRepository(api: api);

    final session = await repository.loginWithSmsCode(
      phone: '13800138000',
      code: '654321',
    );

    expect(session.token, 'jwt-token');
    expect(session.accountId, 10001);
    expect(session.passwordSetupRequired, isTrue);
  });

  test('repository reads password login and sendSmsCode', () async {
    final api = _FakeAuthApi();
    final repository = DefaultAuthRepository(api: api);

    final session = await repository.loginWithPassword(
      identifier: '13800138000',
      password: 'rainy123',
    );
    final code = await repository.sendSmsCode('13800138000');

    expect(session.token, 'password-token');
    expect(api.lastIdentifier, '13800138000');
    expect(api.lastPassword, 'rainy123');
    expect(code, '654321');
  });
}

class _FakeAuthApi implements AuthApi {
  String? lastIdentifier;
  String? lastPassword;

  @override
  Future<AuthSessionDto> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    lastIdentifier = identifier;
    lastPassword = password;
    return const AuthSessionDto(
      token: 'password-token',
      accountId: 10001,
      passwordSetupRequired: false,
    );
  }

  @override
  Future<AuthSessionDto> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    return const AuthSessionDto(
      token: 'jwt-token',
      accountId: 10001,
      passwordSetupRequired: true,
    );
  }

  @override
  Future<SmsCodeDto> sendSmsCode({required String phone}) async {
    return SmsCodeDto(phone: phone, code: '654321');
  }
}
