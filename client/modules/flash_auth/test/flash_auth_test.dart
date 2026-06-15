import 'package:flash_auth/flash_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports login methods', () {
    expect(LoginMethod.values, hasLength(2));
    expect(LoginMethod.smsCode.name, 'smsCode');
    expect(LoginMethod.password.name, 'password');
  });
}
