import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'gets a hidden private conversation by peer and hides it from home',
    () async {
      final adapter = _RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = DioConversationRepository(dio: dio);

      final conversation = await repository.getPrivateByPeerId(3);
      await repository.hideFromList(conversation.id);

      expect(conversation.id, 'private-1');
      expect(conversation.peerUserId, '3');
      expect(adapter.requests.map((request) => request.method), [
        'GET',
        'DELETE',
      ]);
      expect(adapter.requests.first.path, '/conversations/private/3');
      expect(adapter.requests.last.path, '/conversations/private-1');
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final payload = options.method == 'DELETE'
        ? const <String, dynamic>{'message': 'conversation hidden from list'}
        : const <String, dynamic>{
            'id': 'private-1',
            'type': 0,
            'peer_user_id': '3',
            'peer_nickname': '阿青',
            'unread_count': 0,
            'created_at': '2026-09-04T08:00:00Z',
          };
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
