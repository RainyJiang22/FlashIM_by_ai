import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChatPage renders input', (tester) async {
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

    expect(find.text('输入消息'), findsOneWidget);
    expect(find.text('朱红'), findsOneWidget);
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
}

class _FakeMessageRepository implements MessageRepository {
  const _FakeMessageRepository();

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  }) async {
    return const [];
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
