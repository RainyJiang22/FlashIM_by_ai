import 'dart:async';

import 'package:flash_im_chat/src/data/message.dart';
import 'package:flash_im_chat/src/data/message_repository.dart';
import 'package:flash_im_chat/src/data/read_receipt.dart';
import 'package:flash_im_chat/src/view/message_read_status_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final message = Message(
    id: 'message-1',
    conversationId: 'group-1',
    senderId: '1',
    senderName: '我',
    seq: 9,
    content: 'hello',
    status: MessageStatus.sent,
    createdAt: DateTime(2026, 9, 3),
  );

  testWidgets('shows loading and read/unread member tabs', (tester) async {
    final completer = Completer<MessageReadStatus>();
    final repository = _ReadStatusRepository(() => completer.future);

    await tester.pumpWidget(_TestApp(repository: repository, message: message));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_status);
    await tester.pumpAndSettle();

    expect(find.text('消息已读详情'), findsOneWidget);
    expect(find.text('已读 1'), findsOneWidget);
    expect(find.text('未读 1'), findsOneWidget);
    expect(find.text('阿青'), findsOneWidget);

    await tester.tap(find.text('未读 1'));
    await tester.pumpAndSettle();
    expect(find.text('白露'), findsOneWidget);
    expect(repository.calls, 1);
  });

  testWidgets('retries after read status request fails', (tester) async {
    var shouldFail = true;
    final repository = _ReadStatusRepository(() async {
      if (shouldFail) {
        shouldFail = false;
        throw StateError('network failed');
      }
      return _status;
    });

    await tester.pumpWidget(_TestApp(repository: repository, message: message));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('已读详情加载失败'), findsOneWidget);
    await tester.tap(find.byKey(const Key('read-status-retry')));
    await tester.pumpAndSettle();

    expect(find.text('消息已读详情'), findsOneWidget);
    expect(repository.calls, 2);
  });
}

const _status = MessageReadStatus(
  messageId: 'message-1',
  conversationId: 'group-1',
  seq: 9,
  readMembers: [ReadStatusMember(userId: '2', nickname: '阿青', avatar: '')],
  unreadMembers: [ReadStatusMember(userId: '3', nickname: '白露', avatar: '')],
);

class _TestApp extends StatelessWidget {
  const _TestApp({required this.repository, required this.message});

  final MessageRepository repository;
  final Message message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMessageReadStatusSheet(
              context: context,
              repository: repository,
              message: message,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

class _ReadStatusRepository
    implements MessageRepository, MessageReadStatusRepository {
  _ReadStatusRepository(this._load);

  final Future<MessageReadStatus> Function() _load;
  int calls = 0;

  @override
  Future<MessageReadStatus> getReadStatus({
    required String conversationId,
    required String messageId,
  }) {
    calls += 1;
    return _load();
  }

  @override
  Future<String> downloadFile(
    String url,
    String savePath, {
    TransferProgress? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  }) => throw UnimplementedError();

  @override
  Future<FileUploadResult> uploadFile(
    String filePath, {
    TransferProgress? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<ImageUploadResult> uploadImage(
    String filePath, {
    TransferProgress? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<VideoUploadResult> uploadVideo(
    String videoPath,
    String thumbPath,
    int durationMs, {
    int? width,
    int? height,
    TransferProgress? onProgress,
  }) => throw UnimplementedError();
}
