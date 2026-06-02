import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/core/network/dio_factory.dart';
import 'package:flash_im/playground/demos/conversation/data/conversation_api.dart';
import 'package:flash_im/playground/demos/conversation/data/models/conversation_dto.dart';

void main() {
  late HttpServer server;
  late String responseBody;

  setUp(() async {
    responseBody = File(
      'test/playground/conversation/fixtures/conversation_list_fixture.json',
    ).readAsStringSync();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) async {
      if (request.uri.path != '/conversation') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      request.response.headers.contentType = ContentType.json;
      request.response.write(responseBody);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test(
    'fetchConversations parses conversation dto list from dio response',
    () async {
      final api = DioConversationApi(
        dio: DioFactory.create(
          baseUrl: 'http://${server.address.address}:${server.port}',
        ),
      );

      final conversations = await api.fetchConversations();

      expect(conversations, hasLength(20));
      expect(conversations.first, isA<ConversationDto>());
      expect(conversations.first.title, '产品讨论群');
      expect(conversations.first.lastMessage, '今晚先把登录流程对齐一下。');
      expect(conversations.last.title, '系统消息');
    },
  );
}
