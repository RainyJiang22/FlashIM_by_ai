import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Conversation.fromJson maps backend snake_case payload', () {
    final conversation = Conversation.fromJson({
      'id': 'uuid-1',
      'type': 0,
      'name': null,
      'peer_user_id': '3',
      'peer_nickname': '橘橙',
      'peer_avatar': 'identicon:3',
      'last_message_at': '2026-03-29T09:12:00Z',
      'last_message_preview': '你好',
      'unread_count': 2,
      'created_at': '2026-03-29T08:00:00Z',
    });

    expect(conversation.id, 'uuid-1');
    expect(conversation.type, 0);
    expect(conversation.peerUserId, '3');
    expect(conversation.peerNickname, '橘橙');
    expect(conversation.peerAvatar, 'identicon:3');
    expect(conversation.lastMessageAt, DateTime.parse('2026-03-29T09:12:00Z'));
    expect(conversation.lastMessagePreview, '你好');
    expect(conversation.unreadCount, 2);
    expect(conversation.createdAt, DateTime.parse('2026-03-29T08:00:00Z'));
  });

  test('display fields fallback for empty private conversation', () {
    final createdAt = DateTime(2026, 3, 29, 8);
    final conversation = Conversation(
      id: 'uuid-2',
      type: 0,
      peerUserId: '10002',
      unreadCount: 0,
      createdAt: createdAt,
    );

    expect(conversation.displayName, '用户 10002');
    expect(conversation.displayPreview, '暂无消息');
    expect(conversation.displayTime, createdAt);
    expect(conversation.avatarSeed, '10002');
  });

  test('Conversation.fromJson maps immutable group fields', () {
    final conversation = Conversation.fromJson({
      'id': 'group-1',
      'type': 1,
      'name': '橘橙、藤黄、月白',
      'avatar': null,
      'owner_id': 1,
      'member_avatars': ['identicon:1', '', 'identicon:2'],
      'unread_count': 0,
      'created_at': '2026-08-16T08:00:00Z',
    });

    expect(conversation.isGroupChat, isTrue);
    expect(conversation.ownerId, '1');
    expect(conversation.memberAvatars, ['identicon:1', 'identicon:2']);
    expect(
      () => conversation.memberAvatars.add('identicon:3'),
      throwsUnsupportedError,
    );
  });

  test('Conversation.fromJson treats missing member avatars as empty', () {
    final conversation = Conversation.fromJson({
      'id': 'group-2',
      'type': 1,
      'name': '空头像群',
      'unread_count': 0,
      'created_at': '2026-08-16T08:00:00Z',
    });

    expect(conversation.memberAvatars, isEmpty);
  });

  test('avatarSeed prefers peer user id over avatar protocol value', () {
    final conversation = Conversation(
      id: 'uuid-3',
      type: 0,
      peerUserId: '10003',
      peerAvatar: 'identicon:3',
      unreadCount: 0,
      createdAt: DateTime(2026, 3, 29, 8),
    );

    expect(conversation.avatarSeed, '10003');
  });

  testWidgets('conversation tile passes raw avatar protocol to AvatarWidget', (
    tester,
  ) async {
    final conversation = Conversation(
      id: 'uuid-4',
      type: 0,
      peerUserId: '3',
      peerNickname: '橘橙',
      peerAvatar: 'identicon:3',
      unreadCount: 0,
      createdAt: DateTime(2026, 3, 29, 8),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConversationTile(conversation: conversation)),
      ),
    );

    final avatar = tester.widget<AvatarWidget>(find.byType(AvatarWidget));
    expect(avatar.avatar, 'identicon:3');
    expect(avatar.seed, '3');
  });

  testWidgets('group conversation tile uses composite group avatar', (
    tester,
  ) async {
    final conversation = Conversation(
      id: 'group-3',
      type: 1,
      name: '群聊',
      memberAvatars: const ['identicon:1', 'identicon:2', 'identicon:3'],
      unreadCount: 0,
      createdAt: DateTime(2026, 8, 16),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConversationTile(conversation: conversation)),
      ),
    );

    expect(find.byType(GroupAvatar), findsOneWidget);
    expect(find.byType(AvatarWidget), findsNWidgets(3));
  });

  testWidgets('group avatar covers empty, one, two and four member layouts', (
    tester,
  ) async {
    Future<void> pump(List<String> avatars) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupAvatar(avatars: avatars, seed: 'group-layout'),
          ),
        ),
      );
    }

    await pump(const []);
    expect(find.byType(AvatarWidget), findsOneWidget);
    await pump(const ['identicon:1']);
    expect(find.byType(AvatarWidget), findsOneWidget);
    await pump(const ['identicon:1', 'identicon:2']);
    expect(find.byType(AvatarWidget), findsNWidgets(2));
    await pump(const [
      'identicon:1',
      'identicon:2',
      'identicon:3',
      'identicon:4',
    ]);
    expect(find.byType(AvatarWidget), findsNWidgets(4));
  });

  test('created_at is required', () {
    expect(
      () => Conversation.fromJson({'id': 'uuid-1'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('placeholder creates local skeleton conversation', () {
    final time = DateTime(2026, 4, 2, 9);
    final conversation = Conversation.placeholder(
      id: 'c1',
      lastMessagePreview: '新消息',
      lastMessageAt: time,
      unreadCount: 3,
    );

    expect(conversation.id, 'c1');
    expect(conversation.displayPreview, '新消息');
    expect(conversation.displayTime, time);
    expect(conversation.unreadCount, 3);
  });

  test('repository filters group list and sends create body', () async {
    final adapter = _FakeAdapter({
      '/conversations': {
        'id': 'group-4',
        'type': 1,
        'name': '测试群',
        'owner_id': '1',
        'member_avatars': <String>[],
        'unread_count': 0,
        'created_at': '2026-08-16T08:00:00Z',
      },
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9600'));
    dio.httpClientAdapter = adapter;
    final repository = DioConversationRepository(dio: dio);

    await repository.getList(limit: 10, offset: 20, type: 1);
    final created = await repository.createGroup(
      name: '测试群',
      memberIds: const [2, 3],
    );

    expect(adapter.requests.first.queryParameters, {
      'limit': 10,
      'offset': 20,
      'type': 1,
    });
    expect(adapter.requests.last.data, {
      'type': 'group',
      'name': '测试群',
      'member_ids': [2, 3],
    });
    expect(created.id, 'group-4');
  });

  test('repository rejects non-object create response', () async {
    final adapter = _FakeAdapter({'/conversations': <String>[]});
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9600'));
    dio.httpClientAdapter = adapter;
    final repository = DioConversationRepository(dio: dio);

    expect(
      repository.createGroup(name: '测试群', memberIds: const [2, 3]),
      throwsA(isA<FormatException>()),
    );
  });

  test('repository gets detail and marks it read', () async {
    final adapter = _FakeAdapter({
      '/conversations/group-5': {
        'id': 'group-5',
        'type': 1,
        'name': '详情群',
        'unread_count': 0,
        'created_at': '2026-08-16T08:00:00Z',
      },
      '/conversations/group-5/read': null,
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9600'));
    dio.httpClientAdapter = adapter;
    final repository = DioConversationRepository(dio: dio);

    final detail = await repository.getById('group-5');
    await repository.markRead('group-5');

    expect(detail.name, '详情群');
    expect(adapter.requests.map((request) => request.method), ['GET', 'POST']);
  });

  test('member avatar payload must be a list', () {
    expect(
      () => Conversation.fromJson({
        'id': 'bad-group',
        'type': 1,
        'member_avatars': 'invalid',
        'created_at': '2026-08-16T08:00:00Z',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('repository maps Dio create error to domain exception', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9600'));
    dio.httpClientAdapter = _ErrorAdapter();
    final repository = DioConversationRepository(dio: dio);

    expect(
      repository.createGroup(name: '测试群', memberIds: const [2, 3]),
      throwsA(
        isA<ConversationRequestException>().having(
          (error) => error.serverMessage,
          'serverMessage',
          '群成员无效',
        ),
      ),
    );
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.response);

  final Map<String, dynamic> response;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final payload = response[Uri.parse(options.path).path];
    return ResponseBody.fromString(
      jsonEncode(
        options.method == 'GET' &&
                Uri.parse(options.path).path == '/conversations'
            ? [payload]
            : payload,
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'message': '群成员无效'}),
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
