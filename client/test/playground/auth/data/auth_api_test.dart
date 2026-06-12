import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/core/network/dio_factory.dart';
import 'package:flash_im/playground/demos/auth/data/auth_api.dart';

void main() {
  late HttpServer server;
  late String? lastAuthorizationHeader;
  late Map<String, dynamic>? lastLoginPayload;

  setUp(() async {
    lastAuthorizationHeader = null;
    lastLoginPayload = null;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) async {
      if (request.method == 'POST' && request.uri.path == '/auth/sms') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'phone': '13800138000',
            'code': '654321',
          }),
        );
        await request.response.close();
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/auth/login') {
        final body = await utf8.decoder.bind(request).join();
        lastLoginPayload = jsonDecode(body) as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{'token': 'jwt-token', 'user_id': 7}),
        );
        await request.response.close();
        return;
      }

      if (request.method == 'GET' && request.uri.path == '/user/profile') {
        lastAuthorizationHeader = request.headers.value('authorization');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'user_id': 7,
            'nickname': '13800138000',
            'avatar': 'https://picsum.photos/seed/test-seed/120/120',
            'phone': '13800138000',
          }),
        );
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('auth api parses sms login and profile payloads', () async {
    final api = DioAuthApi(
      dio: DioFactory.create(
        baseUrl: 'http://${server.address.address}:${server.port}',
      ),
    );

    final sms = await api.sendSmsCode('13800138000');
    final session = await api.loginWithSmsCode(
      phone: '13800138000',
      code: '654321',
    );
    final profile = await api.fetchProfile(token: 'jwt-token');

    expect(sms.phone, '13800138000');
    expect(sms.code, '654321');
    expect(session.token, 'jwt-token');
    expect(session.userId, 7);
    expect(profile.userId, 7);
    expect(profile.avatar, 'https://picsum.photos/seed/test-seed/120/120');
    expect(lastAuthorizationHeader, 'Bearer jwt-token');
    expect(lastLoginPayload, <String, dynamic>{
      'login_type': 'sms_code',
      'phone': '13800138000',
      'code': '654321',
    });
  });

  test('auth api sends password login payload', () async {
    final api = DioAuthApi(
      dio: DioFactory.create(
        baseUrl: 'http://${server.address.address}:${server.port}',
      ),
    );

    final session = await api.loginWithPassword(
      account: 'rainy',
      password: 'rainy123',
    );

    expect(session.token, 'jwt-token');
    expect(lastLoginPayload, <String, dynamic>{
      'login_type': 'password',
      'account': 'rainy',
      'password': 'rainy123',
    });
  });
}
