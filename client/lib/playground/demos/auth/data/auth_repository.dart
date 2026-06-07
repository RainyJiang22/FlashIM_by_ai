import '../domain/auth_profile.dart';
import '../domain/auth_session.dart';
import '../domain/sms_code_info.dart';
import 'auth_api.dart';
import 'auth_session_store.dart';
import 'models/auth_profile_dto.dart';
import 'models/auth_session_dto.dart';
import 'models/sms_code_dto.dart';

abstract interface class AuthRepository {
  Future<String?> readToken();

  Future<SmsCodeInfo> sendSmsCode(String phone);

  Future<AuthSession> loginWithPassword({
    required String account,
    required String password,
  });

  Future<AuthSession> loginWithSmsCode({
    required String phone,
    required String code,
  });

  Future<AuthProfile> fetchProfile();

  Future<void> logout();
}

class PlaygroundAuthRepository implements AuthRepository {
  PlaygroundAuthRepository({
    required AuthRequest request,
    required AuthSessionStore sessionStore,
  }) : _request = request,
       _sessionStore = sessionStore;

  final AuthRequest _request;
  final AuthSessionStore _sessionStore;

  @override
  Future<AuthProfile> fetchProfile() async {
    final token = await _sessionStore.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthMissingTokenException();
    }

    final dto = await _request.fetchProfile(token: token);
    return _mapProfile(dto);
  }

  @override
  Future<AuthSession> loginWithPassword({
    required String account,
    required String password,
  }) async {
    final dto = await _request.loginWithPassword(
      account: account,
      password: password,
    );
    await _sessionStore.saveToken(dto.token);
    return _mapSession(dto);
  }

  @override
  Future<AuthSession> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    final dto = await _request.loginWithSmsCode(phone: phone, code: code);
    await _sessionStore.saveToken(dto.token);
    return _mapSession(dto);
  }

  @override
  Future<void> logout() => _sessionStore.clearToken();

  @override
  Future<String?> readToken() => _sessionStore.readToken();

  @override
  Future<SmsCodeInfo> sendSmsCode(String phone) async {
    final dto = await _request.sendSmsCode(phone);
    return _mapSmsCode(dto);
  }

  AuthProfile _mapProfile(AuthProfileDto dto) {
    return AuthProfile(
      userId: dto.userId,
      nickname: dto.nickname,
      avatarUrl: dto.avatar,
      phone: dto.phone,
    );
  }

  AuthSession _mapSession(AuthSessionDto dto) {
    return AuthSession(token: dto.token, userId: dto.userId);
  }

  SmsCodeInfo _mapSmsCode(SmsCodeDto dto) {
    return SmsCodeInfo(phone: dto.phone, code: dto.code);
  }
}

class AuthMissingTokenException implements Exception {
  const AuthMissingTokenException();

  @override
  String toString() => 'AuthMissingTokenException: token not found.';
}
