import 'dart:io';

import 'package:dio/dio.dart';

Future<void> main() async {
  const baseUrl = String.fromEnvironment(
    'FLASH_IM_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:9600',
  );
  const phone = String.fromEnvironment(
    'FLASH_IM_TEST_PHONE',
    defaultValue: '13800010001',
  );
  const password = String.fromEnvironment(
    'FLASH_IM_TEST_PASSWORD',
    defaultValue: '111111',
  );

  final dio = Dio(
    BaseOptions(baseUrl: baseUrl, responseType: ResponseType.json),
  );
  final response = await dio.post<dynamic>(
    '/auth/login',
    data: <String, String>{
      'login_type': 'password',
      'identifier': phone,
      'password': password,
    },
  );
  final payload = response.data;
  if (payload is! Map || payload['token'] is! String) {
    throw const FormatException('Login response does not contain token.');
  }

  final envFile = File.fromUri(Platform.script.resolve('.env'));
  await envFile.writeAsString(
    [
      'FLASH_IM_API_BASE_URL=$baseUrl',
      "FLASH_IM_TOKEN=${payload['token']}",
      '',
    ].join('\n'),
  );

  stdout.writeln('Wrote ${envFile.path}');
}
