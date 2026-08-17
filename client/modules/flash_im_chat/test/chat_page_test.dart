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
            onDetailsTap: () async => original.copyWith(name: '新群名'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('旧群名'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-details-action')));
    await tester.pump();
    expect(find.text('新群名'), findsOneWidget);
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
}
