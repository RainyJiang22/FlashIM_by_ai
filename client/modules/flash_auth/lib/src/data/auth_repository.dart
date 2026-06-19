import '../domain/app_session.dart';
import 'auth_api.dart';
import 'models/auth_session_dto.dart';

abstract interface class AuthRepository {
  Future<String> sendSmsCode(String phone);

  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  });

  Future<AppSession> loginWithSmsCode({
    required String phone,
    required String code,
  });
}

class DefaultAuthRepository implements AuthRepository {
  DefaultAuthRepository({required AuthApi api}) : _api = api;

  final AuthApi _api;

  @override
  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    final dto = await _api.loginWithPassword(
      identifier: identifier,
      password: password,
    );
    return _mapSession(dto);
  }

  @override
  Future<AppSession> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    final dto = await _api.loginWithSmsCode(phone: phone, code: code);
    return _mapSession(dto);
  }

  @override
  Future<String> sendSmsCode(String phone) async {
    final dto = await _api.sendSmsCode(phone: phone);
    return dto.code;
  }

  AppSession _mapSession(AuthSessionDto dto) {
    return AppSession(
      token: dto.token,
      accountId: dto.accountId,
      passwordSetupRequired: dto.passwordSetupRequired,
    );
  }
}
