import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/playground/demos/auth/data/auth_api.dart';
import 'package:flash_im/playground/demos/auth/data/auth_repository.dart';
import 'package:flash_im/playground/demos/auth/data/auth_session_store.dart';
import 'package:flash_im/playground/demos/auth/data/models/auth_profile_dto.dart';
import 'package:flash_im/playground/demos/auth/data/models/auth_session_dto.dart';
import 'package:flash_im/playground/demos/auth/data/models/sms_code_dto.dart';

void main() {
  test('repository saves token and auto-carries it for profile requests', () async {
    final request = _FakeAuthRequest();
    final sessionStore = _InMemoryAuthSessionStore();
    final repository = PlaygroundAuthRepository(
      request: request,
      sessionStore: sessionStore,
    );

    final sms = await repository.sendSmsCode('13800138000');
    final session = await repository.login(
      phone: '13800138000',
      code: '654321',
    );
    final profile = await repository.fetchProfile();

    expect(sms.code, '654321');
    expect(session.token, 'jwt-token');
    expect(await sessionStore.readToken(), 'jwt-token');
    expect(request.lastToken, 'jwt-token');
    expect(profile.avatarUrl, 'https://picsum.photos/seed/demo-user/120/120');

    await repository.logout();
    expect(await sessionStore.readToken(), isNull);
  });
}

class _FakeAuthRequest implements AuthRequest {
  String? lastToken;

  @override
  Future<AuthProfileDto> fetchProfile({required String token}) async {
    lastToken = token;
    return const AuthProfileDto(
      userId: 7,
      nickname: '13800138000',
      avatar: 'https://picsum.photos/seed/demo-user/120/120',
      phone: '13800138000',
    );
  }

  @override
  Future<AuthSessionDto> login({
    required String phone,
    required String code,
  }) async {
    return const AuthSessionDto(token: 'jwt-token', userId: 7);
  }

  @override
  Future<SmsCodeDto> sendSmsCode(String phone) async {
    return const SmsCodeDto(phone: '13800138000', code: '654321');
  }
}

class _InMemoryAuthSessionStore implements AuthSessionStore {
  String? _token;

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }
}
