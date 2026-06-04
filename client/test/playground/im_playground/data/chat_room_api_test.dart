import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/playground/demos/im_playground/data/chat_room_api.dart';
import 'package:flash_im/playground/demos/im_playground/domain/chat_room_connection_status.dart';

void main() {
  late HttpServer server;
  late String? lastToken;

  setUp(() async {
    lastToken = null;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      lastToken = request.uri.queryParameters['token'];
      final webSocket = await WebSocketTransformer.upgrade(request);
      webSocket.add(
        jsonEncode(<String, dynamic>{
          'type': 'auth_ready',
          'user_id': 7,
          'nickname': '汪萱',
          'avatar': 'https://picsum.photos/seed/peer/120/120',
        }),
      );

      webSocket.listen((dynamic payload) {
        final decoded = jsonDecode(payload as String) as Map<String, dynamic>;
        switch (decoded['type']) {
          case 'ping':
            webSocket.add(
              jsonEncode(<String, dynamic>{'type': 'pong', 'sent_at': 1}),
            );
          case 'chat':
            webSocket.add(
              jsonEncode(<String, dynamic>{
                'type': 'chat',
                'message_id': 9,
                'user_id': 7,
                'nickname': '汪萱',
                'avatar': 'https://picsum.photos/seed/peer/120/120',
                'text': decoded['text'],
                'sent_at': 2,
              }),
            );
        }
      });
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test(
    'chat room api connects with token and parses incoming frames',
    () async {
      final api = WebSocketChatRoomApi();
      final events = <ChatRoomApiEvent>[];
      final done = Completer<void>();

      final subscription = api
          .connect(
            baseUrl: 'http://${server.address.address}:${server.port}',
            token: 'jwt-token',
          )
          .listen((event) {
            events.add(event);
            if (events.any((item) => item.frame?.type == 'chat')) {
              done.complete();
            }
          });

      await api.sendHeartbeat();
      await api.sendChat('hello room');
      await done.future.timeout(const Duration(seconds: 3));

      expect(lastToken, 'jwt-token');
      expect(
        events.any(
          (event) =>
              event.type == ChatRoomApiEventType.status &&
              event.status == ChatRoomConnectionStatus.connected,
        ),
        isTrue,
      );
      expect(events.any((event) => event.frame?.type == 'auth_ready'), isTrue);
      expect(events.any((event) => event.frame?.type == 'pong'), isTrue);
      expect(
        events.any(
          (event) =>
              event.frame?.type == 'chat' && event.frame?.text == 'hello room',
        ),
        isTrue,
      );

      await subscription.cancel();
      await api.disconnect();
    },
  );
}
