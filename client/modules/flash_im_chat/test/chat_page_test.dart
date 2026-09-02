import 'dart:async';

import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChatPage renders input', (tester) async {
    var detailsTapped = false;
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MessageRepository>.value(
            value: const _FakeMessageRepository(),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: MaterialApp(
          home: ChatPage(
            conversation: Conversation(
              id: 'c1',
              type: 0,
              peerNickname: '朱红',
              unreadCount: 0,
              createdAt: DateTime(2026, 4, 2),
            ),
            currentUserId: '1',
            onDetailsTap: () async {
              detailsTapped = true;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('输入消息'), findsOneWidget);
    expect(find.text('朱红'), findsOneWidget);
    expect(find.byKey(const Key('chat-details-action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-details-action')));
    expect(detailsTapped, isTrue);
  });

  testWidgets('plus button expands media action panel', (tester) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MessageRepository>.value(
            value: const _FakeMessageRepository(),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: MaterialApp(
          home: ChatPage(
            conversation: Conversation(
              id: 'c1',
              type: 0,
              peerNickname: '朱红',
              unreadCount: 0,
              createdAt: DateTime(2026, 4, 2),
            ),
            currentUserId: '1',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    expect(find.text('照片'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(find.text('文件'), findsOneWidget);
    final panel = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .last;
    expect(panel.constraints?.maxHeight, 112);
  });

  testWidgets('group details callback hot-updates the app bar title', (
    tester,
  ) async {
    final original = Conversation(
      id: 'group-1',
      type: 1,
      name: '旧群名',
      unreadCount: 0,
      createdAt: DateTime(2026, 8, 17),
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MessageRepository>.value(
            value: const _FakeMessageRepository(),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: MaterialApp(
          home: ChatPage(
            conversation: original,
            currentUserId: '1',
            onDetailsTap: () async =>
                original.copyWith(name: '新群名', announcement: '新群公告'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('旧群名'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-details-action')));
    await tester.pump();
    expect(find.text('新群名'), findsOneWidget);
    expect(find.text('新群公告'), findsOneWidget);
    expect(find.byKey(const Key('chat-announcement-banner')), findsOneWidget);
  });

  testWidgets(
    'membership inactive does not pop a typed details route with bool',
    (tester) async {
      final wsClient = _FakeWsClient();
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<MessageRepository>.value(
              value: const _FakeMessageRepository(),
            ),
            RepositoryProvider<WsClient>.value(value: wsClient),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ChatPage(
                conversation: Conversation(
                  id: 'group-1',
                  type: 1,
                  name: '测试群',
                  unreadCount: 0,
                  createdAt: DateTime(2026, 9, 2),
                ),
                currentUserId: '1',
                onDetailsTap: () async {
                  await Navigator.of(context).push<String>(
                    MaterialPageRoute<String>(
                      builder: (_) =>
                          const Scaffold(body: Center(child: Text('强类型群详情'))),
                    ),
                  );
                  return null;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat-details-action')));
      await tester.pumpAndSettle();
      expect(find.text('强类型群详情'), findsOneWidget);

      wsClient.addGroupInfo(
        GroupInfoUpdateNotification(
          conversationId: 'group-1',
          membershipActive: false,
          changeType: 'member_left',
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('强类型群详情'), findsOneWidget);

      Navigator.of(tester.element(find.text('强类型群详情'))).pop('left');
      await tester.pumpAndSettle();
      expect(find.text('测试群'), findsOneWidget);
      await wsClient.closeEvents();
    },
  );

  testWidgets('membership inactive still closes the current chat route', (
    tester,
  ) async {
    final wsClient = _FakeWsClient();
    bool? routeResult;
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MessageRepository>.value(
            value: const _FakeMessageRepository(),
          ),
          RepositoryProvider<WsClient>.value(value: wsClient),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  routeResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => ChatPage(
                        conversation: Conversation(
                          id: 'group-1',
                          type: 1,
                          name: '测试群',
                          unreadCount: 0,
                          createdAt: DateTime(2026, 9, 2),
                        ),
                        currentUserId: '1',
                      ),
                    ),
                  );
                },
                child: const Text('打开群聊'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开群聊'));
    await tester.pumpAndSettle();
    expect(find.text('测试群'), findsOneWidget);

    wsClient.addGroupInfo(
      GroupInfoUpdateNotification(
        conversationId: 'group-1',
        membershipActive: false,
        changeType: 'member_left',
      ),
    );
    await tester.pumpAndSettle();

    expect(routeResult, isTrue);
    expect(find.text('打开群聊'), findsOneWidget);
    await wsClient.closeEvents();
  });

  testWidgets('group announcement stays pinned below the app bar', (
    tester,
  ) async {
    var detailsTapped = false;
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MessageRepository>.value(
            value: const _FakeMessageRepository(),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: MaterialApp(
          home: ChatPage(
            conversation: Conversation(
              id: 'group-1',
              type: 1,
              name: '测试群',
              announcement: '大家理性讨论，共同进步～',
              unreadCount: 0,
              createdAt: DateTime(2026, 9, 1),
            ),
            currentUserId: '1',
            onDetailsTap: () async {
              detailsTapped = true;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-announcement-banner')), findsOneWidget);
    expect(find.text('大家理性讨论，共同进步～'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-announcement-banner')));
    expect(detailsTapped, isTrue);
  });

  testWidgets('renders loaded message list', (tester) async {
    final message = Message(
      id: 'm1',
      conversationId: 'c1',
      senderId: '2',
      senderName: '朱红',
      seq: 1,
      content: '群聊消息',
      status: MessageStatus.sent,
      createdAt: DateTime(2026, 8, 16),
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MessageRepository>.value(
            value: _FakeMessageRepository(messages: [message]),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: MaterialApp(
          home: ChatPage(
            conversation: Conversation(
              id: 'c1',
              type: 1,
              name: '测试群',
              unreadCount: 0,
              createdAt: DateTime(2026, 8, 16),
            ),
            currentUserId: '1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('群聊消息'), findsOneWidget);
    expect(find.byKey(const Key('chat-details-action')), findsNothing);
  });

  testWidgets('renders message load error', (tester) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MessageRepository>.value(
            value: const _FakeMessageRepository(error: true),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: MaterialApp(
          home: ChatPage(
            conversation: Conversation(
              id: 'c1',
              type: 0,
              peerNickname: '朱红',
              unreadCount: 0,
              createdAt: DateTime(2026, 8, 16),
            ),
            currentUserId: '1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('消息加载失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('dissolved group keeps history and replaces all send controls', (
    tester,
  ) async {
    final message = Message(
      id: 'm1',
      conversationId: 'group-1',
      senderId: '2',
      senderName: '阿青',
      seq: 1,
      content: '历史消息',
      status: MessageStatus.sent,
      createdAt: DateTime(2026, 8, 31),
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MessageRepository>.value(
            value: _FakeMessageRepository(messages: [message]),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: MaterialApp(
          home: ChatPage(
            conversation: Conversation(
              id: 'group-1',
              type: 1,
              name: '已解散群',
              unreadCount: 0,
              isDissolved: true,
              createdAt: DateTime(2026, 8, 31),
            ),
            currentUserId: '1',
            onDetailsTap: () async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('历史消息'), findsOneWidget);
    expect(find.byKey(const Key('dissolved-chat-readonly')), findsOneWidget);
    expect(find.text('该群聊已解散'), findsOneWidget);
    expect(find.text('输入消息'), findsNothing);
    expect(find.byTooltip('更多'), findsNothing);
    expect(find.byKey(const Key('chat-details-action')), findsNothing);
  });

  testWidgets(
    'group info update changes title and switches chat to read-only',
    (tester) async {
      final wsClient = _FakeWsClient();
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<MessageRepository>.value(
              value: const _FakeMessageRepository(),
            ),
            RepositoryProvider<WsClient>.value(value: wsClient),
          ],
          child: MaterialApp(
            home: ChatPage(
              conversation: Conversation(
                id: 'group-1',
                type: 1,
                name: '旧群名',
                unreadCount: 0,
                createdAt: DateTime(2026, 8, 31),
              ),
              currentUserId: '1',
              onDetailsTap: () async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      wsClient.addGroupInfo(
        GroupInfoUpdateNotification(
          conversationId: 'group-1',
          name: '实时群名',
          memberCount: 2,
          announcement: '实时公告',
          isDissolved: true,
          membershipActive: true,
          currentUserRole: 'member',
          changeType: 'dissolved',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('实时群名'), findsOneWidget);
      expect(find.text('实时公告'), findsOneWidget);
      expect(find.byKey(const Key('chat-announcement-banner')), findsOneWidget);
      expect(find.byKey(const Key('dissolved-chat-readonly')), findsOneWidget);
      expect(find.byKey(const Key('chat-details-action')), findsNothing);
      await wsClient.closeEvents();
    },
  );
}

class _FakeMessageRepository implements MessageRepository {
  const _FakeMessageRepository({this.messages = const [], this.error = false});

  final List<Message> messages;
  final bool error;

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  }) async {
    if (error) {
      throw StateError('load failed');
    }
    return messages;
  }

  @override
  Future<ImageUploadResult> uploadImage(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<VideoUploadResult> uploadVideo(
    String videoPath,
    String thumbPath,
    int durationMs, {
    int? width,
    int? height,
    void Function(int sent, int total)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<FileUploadResult> uploadFile(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<String> downloadFile(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) => throw UnimplementedError();
}

class _FakeWsClient extends WsClient {
  _FakeWsClient()
    : super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
        tokenProvider: () => null,
      );

  final _groupInfo = StreamController<GroupInfoUpdateNotification>.broadcast();

  @override
  Stream<GroupInfoUpdateNotification> get groupInfoUpdateStream =>
      _groupInfo.stream;

  void addGroupInfo(GroupInfoUpdateNotification update) =>
      _groupInfo.add(update);

  Future<void> closeEvents() => _groupInfo.close();
}
