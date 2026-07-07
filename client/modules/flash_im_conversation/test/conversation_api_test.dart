import 'package:dio/dio.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test/test_env.dart' as test_env;

void main() {
  final env = test_env.readTestEnvOrNull();
  if (env == null) {
    test(
      'conversation API skipped without client/test/.env',
      () {},
      skip:
          'Run client/test/login_for_test.dart against a seeded backend first.',
    );
    return;
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: env.baseUrl,
      responseType: ResponseType.json,
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${env.token}',
      },
    ),
  );
  final repository = DioConversationRepository(dio: dio);

  test('fetches first page conversations', () async {
    final conversations = await repository.getList(limit: 20, offset: 0);

    expect(conversations, hasLength(20));
    expect(conversations.first.peerNickname, isNotEmpty);
    expect(conversations.first.peerUserId, isNotEmpty);
    expect(conversations.first.displayPreview, isNotEmpty);
  });

  test('fetches all seeded conversations without duplicate ids', () async {
    final first = await repository.getList(limit: 20, offset: 0);
    final second = await repository.getList(limit: 20, offset: 20);
    final third = await repository.getList(limit: 20, offset: 40);
    final overflow = await repository.getList(limit: 20, offset: 60);
    final conversations = [...first, ...second, ...third];
    final ids = conversations.map((conversation) => conversation.id).toSet();

    expect(conversations, hasLength(51));
    expect(ids, hasLength(51));
    expect(overflow, isEmpty);
  });
}
