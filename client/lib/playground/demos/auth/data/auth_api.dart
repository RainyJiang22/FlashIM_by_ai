import 'package:dio/dio.dart';

import 'models/auth_profile_dto.dart';
import 'models/auth_session_dto.dart';
import 'models/sms_code_dto.dart';

abstract interface class AuthRequest {
  Future<SmsCodeDto> sendSmsCode(String phone);

  Future<AuthSessionDto> loginWithPassword({
    required String account,
    required String password,
  });

  Future<AuthSessionDto> loginWithSmsCode({
    required String phone,
    required String code,
  });

  Future<AuthProfileDto> fetchProfile({required String token});
}

class DioAuthApi implements AuthRequest {
  DioAuthApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<AuthProfileDto> fetchProfile({required String token}) async {
    final response = await _dio.get<dynamic>(
      '/user/profile',
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $token'},
      ),
    );

    return AuthProfileDto.fromJson(_readJsonMap(response.data));
  }

  @override
  Future<AuthSessionDto> loginWithPassword({
    required String account,
    required String password,
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/login',
      data: <String, String>{
        'login_type': 'password',
        'account': account,
        'password': password,
      },
    );

    return AuthSessionDto.fromJson(_readJsonMap(response.data));
  }

  @override
  Future<AuthSessionDto> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/login',
      data: <String, String>{
        'login_type': 'sms_code',
        'phone': phone,
        'code': code,
      },
    );

    return AuthSessionDto.fromJson(_readJsonMap(response.data));
  }

  @override
  Future<SmsCodeDto> sendSmsCode(String phone) async {
    final response = await _dio.post<dynamic>(
      '/auth/sms',
      data: <String, String>{'phone': phone},
    );

    return SmsCodeDto.fromJson(_readJsonMap(response.data));
  }

  Map<String, dynamic> _readJsonMap(dynamic payload) {
    if (payload is! Map) {
      throw const FormatException('Auth payload is not a JSON object.');
    }

    return Map<String, dynamic>.from(payload);
  }
}
