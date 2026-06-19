import 'package:dio/dio.dart';

import 'user.dart';

abstract interface class SessionApi {
  Future<User> fetchProfile({required String token});

  Future<User> updateProfile({
    required String token,
    String? nickname,
    String? signature,
    String? avatar,
  });

  Future<void> setPassword({
    required String token,
    required String newPassword,
  });

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  });
}

class DioSessionApi implements SessionApi {
  DioSessionApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.put<dynamic>(
      '/user/password',
      data: <String, String>{
        'old_password': oldPassword,
        'new_password': newPassword,
      },
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $token'},
      ),
    );
  }

  @override
  Future<User> fetchProfile({required String token}) async {
    final response = await _dio.get<dynamic>(
      '/user/profile',
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $token'},
      ),
    );

    return User.fromJson(_readJsonMap(response.data));
  }

  @override
  Future<void> setPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dio.post<dynamic>(
      '/user/password',
      data: <String, String>{'new_password': newPassword},
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $token'},
      ),
    );
  }

  @override
  Future<User> updateProfile({
    required String token,
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    final payload = <String, String?>{
      'nickname': nickname,
      'signature': signature,
      'avatar': avatar,
    }..removeWhere((_, value) => value == null);

    final response = await _dio.put<dynamic>(
      '/user/profile',
      data: payload,
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $token'},
      ),
    );

    return User.fromJson(_readJsonMap(response.data));
  }

  Map<String, dynamic> _readJsonMap(dynamic payload) {
    if (payload is! Map) {
      throw const FormatException('Session payload is not a JSON object.');
    }

    return Map<String, dynamic>.from(payload);
  }
}
