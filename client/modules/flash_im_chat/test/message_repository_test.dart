import 'package:dio/dio.dart';
import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DioMessageRepository fetches messages with before_seq', () async {
    RequestOptions? capturedRequest;
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9600/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedRequest = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: [
                {
                  'id': 'm2',
                  'conversation_id': 'c1',
                  'sender_id': 2,
                  'seq': 2,
                  'type': 1,
                  'content': 'second',
                  'status': 1,
                  'created_at': '2026-04-02T09:02:00Z',
                },
                {
                  'id': 'm1',
                  'conversation_id': 'c1',
                  'sender_id': 1,
                  'seq': 1,
                  'type': 1,
                  'content': 'first',
                  'status': 1,
                  'created_at': '2026-04-02T09:01:00Z',
                },
              ],
            ),
          );
        },
      ),
    );

    final repository = DioMessageRepository(dio: dio);
    final messages = await repository.getMessages(
      conversationId: 'c1',
      beforeSeq: 9,
      limit: 20,
    );

    expect(capturedRequest?.path, '/conversations/c1/messages');
    expect(capturedRequest?.queryParameters, {'limit': 20, 'before_seq': 9});
    expect(messages.map((message) => message.id), ['m1', 'm2']);
  });
}
