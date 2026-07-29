import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads friends from the server contract', () async {
    final adapter = _RecordingAdapter((options) {
      expect(options.method, 'GET');
      expect(options.path, '/api/friends');
      return const <Map<String, dynamic>>[
        <String, dynamic>{
          'account_id': 7,
          'nickname': '阿青',
          'avatar': '',
          'signature': '',
          'relation_status': 'friend',
        },
      ];
    });
    final dio = Dio()..httpClientAdapter = adapter;

    final friends = await DioFriendRepository(dio: dio).getFriends();

    expect(friends.single.accountId, 7);
    expect(friends.single.isFriend, isTrue);
  });

  test('sends friend request using the documented body', () async {
    final adapter = _RecordingAdapter((options) {
      expect(options.method, 'POST');
      expect(options.path, '/api/friends/requests');
      expect(options.data, <String, dynamic>{'to_user_id': 9, 'message': '你好'});
      return const <String, dynamic>{'status': 'pending'};
    });
    final dio = Dio()..httpClientAdapter = adapter;

    await DioFriendRepository(dio: dio).sendRequest(toUserId: 9, message: '你好');
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final Object Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payload = handler(options);
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
