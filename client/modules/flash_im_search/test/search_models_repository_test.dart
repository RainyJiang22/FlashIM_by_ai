import 'package:dio/dio.dart';
import 'package:flash_im_search/flash_im_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message group parses existing conversation and message models', () {
    final group = MessageSearchGroup.fromJson(_messageGroupJson());

    expect(group.conversation.id, 'group-1');
    expect(group.conversation.name, '项目群');
    expect(group.matchCount, 2);
    expect(group.messages.single.senderName, '阿青');
  });

  test(
    'dio repository calls four search endpoints and parses payloads',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final data = switch (options.path) {
              '/api/friends/search' => [_friendJson(2, '阿青')],
              '/api/conversations/search-joined-groups' => [
                _conversationJson(),
              ],
              '/api/messages/search' => [_messageGroupJson()],
              '/conversations/group-1/messages/search' => [_messageJson()],
              _ => <dynamic>[],
            };
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );
      final repository = DioSearchRepository(dio: dio);

      expect((await repository.searchFriends('阿青')).single.accountId, 2);
      expect((await repository.searchJoinedGroups('项目')).single.id, 'group-1');
      expect((await repository.searchMessages('发布')).single.matchCount, 2);
      expect(
        (await repository.searchConversationMessages(
          conversationId: 'group-1',
          query: '发布',
        )).single.content,
        '今天发布',
      );
      expect(requests.map((item) => item.queryParameters['q']), [
        '阿青',
        '项目',
        '发布',
        '发布',
      ]);
      expect(requests.last.queryParameters['limit'], 100);
    },
  );

  test('repository rejects malformed list payload', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) =>
            handler.resolve(Response(requestOptions: options, data: {})),
      ),
    );

    expect(
      DioSearchRepository(dio: dio).searchFriends('x'),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _friendJson(int id, String name) => {
  'account_id': id,
  'nickname': name,
  'avatar': 'identicon:$id',
  'signature': '',
  'relation_status': 'friend',
};

Map<String, dynamic> _conversationJson() => {
  'id': 'group-1',
  'type': 1,
  'name': '项目群',
  'unread_count': 0,
  'member_count': 3,
  'member_avatars': <String>[],
  'created_at': '2026-09-04T08:00:00Z',
};

Map<String, dynamic> _messageJson() => {
  'id': 'message-1',
  'conversation_id': 'group-1',
  'sender_id': '2',
  'sender_name': '阿青',
  'sender_avatar': 'identicon:2',
  'seq': 8,
  'msg_type': 0,
  'content': '今天发布',
  'status': 0,
  'created_at': '2026-09-04T09:00:00Z',
  'read_count': 0,
};

Map<String, dynamic> _messageGroupJson() => {
  'conversation': _conversationJson(),
  'match_count': 2,
  'messages': [_messageJson()],
};
