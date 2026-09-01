import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final conversation = Conversation(
    id: 'c1',
    type: 0,
    peerUserId: '2',
    peerNickname: '朱红',
    unreadCount: 0,
    createdAt: DateTime(2026, 4, 2),
  );
  final history = Message(
    id: 'm1',
    conversationId: 'c1',
    senderId: '2',
    senderName: '朱红',
    seq: 1,
    content: 'hello',
    status: MessageStatus.sent,
    createdAt: DateTime(2026, 4, 2, 9),
  );

  blocTest<ChatCubit, ChatState>(
    'loadMessages emits loaded messages',
    build: () => ChatCubit(
      repository: _FakeMessageRepository(messages: [history]),
      wsClient: _FakeWsClient(),
      conversation: conversation,
      currentUserId: '1',
      videoThumbnailService: const _FakeVideoThumbnailService(),
    ),
    act: (cubit) => cubit.loadMessages(),
    expect: () => [
      const ChatLoading(),
      ChatLoaded(messages: [history], hasMore: false),
    ],
  );

  test('text message without ACK becomes failed after 12 seconds', () {
    fakeAsync((async) {
      final wsClient = _FakeWsClient();
      final cubit = ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: wsClient,
        conversation: conversation,
        currentUserId: '1',
        videoThumbnailService: const _FakeVideoThumbnailService(),
      );
      cubit.loadMessages();
      async.flushMicrotasks();
      cubit.sendText('等待确认');
      expect(
        (cubit.state as ChatLoaded).messages.single.status,
        MessageStatus.sending,
      );

      async.elapse(const Duration(seconds: 12));

      expect(
        (cubit.state as ChatLoaded).messages.single.status,
        MessageStatus.failed,
      );
      cubit.close();
      wsClient.dispose();
      async.flushMicrotasks();
    });
  });

  blocTest<ChatCubit, ChatState>(
    'sendText appends sending message',
    build: () {
      return ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: _FakeWsClient(),
        conversation: conversation,
        currentUserId: '1',
        currentUserAvatar: 'identicon:me',
        videoThumbnailService: const _FakeVideoThumbnailService(),
      );
    },
    seed: () => const ChatLoaded(messages: [], hasMore: false),
    act: (cubit) => cubit.sendText('hi'),
    expect: () => [isA<ChatLoaded>()],
    verify: (cubit) {
      final state = cubit.state as ChatLoaded;
      expect(state.messages.single.status, MessageStatus.sending);
      expect(state.messages.single.senderAvatar, 'identicon:me');
    },
  );

  late _FakeWsClient ackWsClient;
  blocTest<ChatCubit, ChatState>(
    'message ack marks first pending message as sent',
    build: () {
      ackWsClient = _FakeWsClient();
      return ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: ackWsClient,
        conversation: conversation,
        currentUserId: '1',
        videoThumbnailService: const _FakeVideoThumbnailService(),
      );
    },
    seed: () => const ChatLoaded(messages: [], hasMore: false),
    act: (cubit) {
      cubit.sendText('hi');
      ackWsClient.emitAck(MessageAck(messageId: 'server-m1', seq: 8));
    },
    expect: () => [isA<ChatLoaded>(), isA<ChatLoaded>()],
    verify: (cubit) {
      final state = cubit.state as ChatLoaded;
      expect(state.messages.single.id, 'server-m1');
      expect(state.messages.single.seq, 8);
      expect(state.messages.single.status, MessageStatus.sent);
    },
  );

  late _FakeWsClient incomingWsClient;
  blocTest<ChatCubit, ChatState>(
    'incoming message from current conversation is appended',
    build: () {
      incomingWsClient = _FakeWsClient();
      return ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: incomingWsClient,
        conversation: conversation,
        currentUserId: '1',
        videoThumbnailService: const _FakeVideoThumbnailService(),
      );
    },
    seed: () => ChatLoaded(messages: [history], hasMore: false),
    act: (cubit) {
      incomingWsClient.emitMessage(
        ChatMessage(
          id: 'm2',
          conversationId: 'c1',
          senderId: 2,
          seq: 2,
          content: 'new',
          createdAt: '2026-04-02T09:02:00Z',
        ),
      );
    },
    expect: () => [isA<ChatLoaded>()],
    verify: (cubit) {
      final state = cubit.state as ChatLoaded;
      expect(state.messages.map((message) => message.id), ['m1', 'm2']);
    },
  );

  late _FakeWsClient systemMessageWsClient;
  blocTest<ChatCubit, ChatState>(
    'own group system message refreshes immediately and keeps persisted text',
    build: () {
      systemMessageWsClient = _FakeWsClient();
      return ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: systemMessageWsClient,
        conversation: conversation,
        currentUserId: '1',
        videoThumbnailService: const _FakeVideoThumbnailService(),
        mediaUrlResolver: (value) => 'http://127.0.0.1:9600/$value',
      );
    },
    seed: () => const ChatLoaded(messages: [], hasMore: false),
    act: (cubit) {
      final events = [
        ('announcement_updated', '系统助手 更新了群公告'),
        ('group_name_updated', '系统助手 将群名修改为「读书会」'),
        ('member_invited', '系统助手 邀请 花青、湖绿等进群'),
      ];
      for (var index = 0; index < events.length; index++) {
        final event = events[index];
        systemMessageWsClient.emitMessage(
          ChatMessage(
            id: 'system-$index',
            conversationId: 'c1',
            senderId: 1,
            senderName: '系统助手',
            seq: index + 3,
            type: 5,
            content: event.$2,
            extra: '{"system_event":"${event.$1}"}',
            createdAt: '2026-09-01T09:02:00Z',
          ),
        );
      }
    },
    expect: () => [isA<ChatLoaded>(), isA<ChatLoaded>(), isA<ChatLoaded>()],
    verify: (cubit) {
      final messages = (cubit.state as ChatLoaded).messages;
      expect(messages.map((message) => message.content), [
        '系统助手 更新了群公告',
        '系统助手 将群名修改为「读书会」',
        '系统助手 邀请 花青、湖绿等进群',
      ]);
      expect(messages.map((message) => message.extra?['system_event']), [
        'announcement_updated',
        'group_name_updated',
        'member_invited',
      ]);
    },
  );

  late _FakeWsClient ignoredWsClient;
  blocTest<ChatCubit, ChatState>(
    'incoming message from another conversation is ignored',
    build: () {
      ignoredWsClient = _FakeWsClient();
      return ChatCubit(
        repository: _FakeMessageRepository(messages: const []),
        wsClient: ignoredWsClient,
        conversation: conversation,
        currentUserId: '1',
        videoThumbnailService: const _FakeVideoThumbnailService(),
      );
    },
    seed: () => ChatLoaded(messages: [history], hasMore: false),
    act: (cubit) {
      ignoredWsClient.emitMessage(
        ChatMessage(id: 'm2', conversationId: 'other', senderId: 2),
      );
    },
    expect: () => const <ChatState>[],
  );

  test('image upload sends media request and ACK marks it sent', () async {
    final wsClient = _FakeWsClient();
    final repository = _MediaMessageRepository();
    final cubit = ChatCubit(
      repository: repository,
      wsClient: wsClient,
      conversation: conversation,
      currentUserId: '1',
      videoThumbnailService: const _FakeVideoThumbnailService(),
    );
    addTearDown(cubit.close);
    addTearDown(wsClient.dispose);
    await cubit.loadMessages();

    await cubit.sendImageFromFile('/tmp/photo.jpg');

    final sending = cubit.state as ChatLoaded;
    expect(sending.messages.single.type, MessageType.image);
    expect(sending.messages.single.extra?['width'], 640);
    expect(sending.uploadProgress, isNull);
    expect(wsClient.sentRequests.single.type, 1);
    expect(wsClient.sentRequests.single.content, endsWith('/photo.jpg'));

    wsClient.emitAck(MessageAck(messageId: 'server-image', seq: 9));
    final sent = cubit.state as ChatLoaded;
    expect(sent.messages.single.id, 'server-image');
    expect(sent.messages.single.status, MessageStatus.sent);
  });

  test('image upload failure keeps existing failed message state', () async {
    final wsClient = _FakeWsClient();
    final cubit = ChatCubit(
      repository: _MediaMessageRepository(failUpload: true),
      wsClient: wsClient,
      conversation: conversation,
      currentUserId: '1',
      videoThumbnailService: const _FakeVideoThumbnailService(),
    );
    addTearDown(cubit.close);
    addTearDown(wsClient.dispose);
    await cubit.loadMessages();

    await cubit.sendImageFromFile('/tmp/photo.jpg');

    final state = cubit.state as ChatLoaded;
    expect(state.messages.single.status, MessageStatus.failed);
  });

  test('video upload uses extracted metadata', () async {
    final temp = await Directory.systemTemp.createTemp('flash_im_video_test');
    addTearDown(() => temp.delete(recursive: true));
    final video = File('${temp.path}/clip.mp4')..writeAsBytesSync([1, 2, 3]);
    final thumbnail = File('${temp.path}/thumb.jpg')..writeAsBytesSync([4]);
    final wsClient = _FakeWsClient();
    final repository = _MediaMessageRepository();
    final cubit = ChatCubit(
      repository: repository,
      wsClient: wsClient,
      conversation: conversation,
      currentUserId: '1',
      videoThumbnailService: _FakeVideoThumbnailService(
        thumbnailPath: thumbnail.path,
      ),
    );
    addTearDown(cubit.close);
    addTearDown(wsClient.dispose);
    await cubit.loadMessages();

    await cubit.sendVideoFromFile(video.path);

    expect(repository.uploadedDurationMs, 1000);
    expect(wsClient.sentRequests.single.type, 2);
    expect((cubit.state as ChatLoaded).messages.single.videoExtra?.width, 320);
  });

  test('file download emits downloading then done', () async {
    final temp = await Directory.systemTemp.createTemp('flash_im_file_test');
    addTearDown(() => temp.delete(recursive: true));
    final wsClient = _FakeWsClient();
    final cubit = ChatCubit(
      repository: _MediaMessageRepository(),
      wsClient: wsClient,
      conversation: conversation,
      currentUserId: '1',
      videoThumbnailService: const _FakeVideoThumbnailService(),
      downloadDirectoryProvider: () async => temp,
    );
    addTearDown(cubit.close);
    addTearDown(wsClient.dispose);
    await cubit.loadMessages();

    await cubit.downloadFile('m-file', '/uploads/file/a.pdf', 'a.pdf');

    final info = (cubit.state as ChatLoaded).fileDownloads['m-file'];
    expect(info?.status, FileDownloadStatus.done);
    expect(info?.progress, 1);
    expect(info?.localPath, contains('a.pdf'));
  });

  test('file download failure is exposed in ChatState', () async {
    final temp = await Directory.systemTemp.createTemp(
      'flash_im_file_error_test',
    );
    addTearDown(() => temp.delete(recursive: true));
    final wsClient = _FakeWsClient();
    final cubit = ChatCubit(
      repository: _MediaMessageRepository(failDownload: true),
      wsClient: wsClient,
      conversation: conversation,
      currentUserId: '1',
      videoThumbnailService: const _FakeVideoThumbnailService(),
      downloadDirectoryProvider: () async => temp,
    );
    addTearDown(cubit.close);
    addTearDown(wsClient.dispose);
    await cubit.loadMessages();

    await cubit.downloadFile('m-file', '/uploads/file/a.pdf', 'a.pdf');

    final info = (cubit.state as ChatLoaded).fileDownloads['m-file'];
    expect(info?.status, FileDownloadStatus.error);
    expect(info?.error, contains('download failed'));
  });
}

class _FakeMessageRepository implements MessageRepository {
  const _FakeMessageRepository({required this.messages});

  final List<Message> messages;

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  }) async {
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

class _FakeVideoThumbnailService implements VideoThumbnailService {
  const _FakeVideoThumbnailService({this.thumbnailPath = '/tmp/thumb.jpg'});

  final String thumbnailPath;

  @override
  Future<VideoThumbnailInfo> extract(String videoPath) async =>
      VideoThumbnailInfo(
        thumbnailPath: thumbnailPath,
        durationMs: 1000,
        width: 320,
        height: 180,
      );
}

class _MediaMessageRepository implements MessageRepository {
  _MediaMessageRepository({this.failDownload = false, this.failUpload = false});

  final bool failDownload;
  final bool failUpload;
  int? uploadedDurationMs;

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  }) async => const [];

  @override
  Future<ImageUploadResult> uploadImage(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    if (failUpload) {
      throw StateError('upload failed');
    }
    onProgress?.call(1, 2);
    onProgress?.call(2, 2);
    return const ImageUploadResult(
      originalUrl: 'http://127.0.0.1:9600/uploads/photo.jpg',
      thumbnailUrl: 'http://127.0.0.1:9600/uploads/thumb.webp',
      width: 640,
      height: 480,
      size: 2,
      format: 'jpg',
    );
  }

  @override
  Future<VideoUploadResult> uploadVideo(
    String videoPath,
    String thumbPath,
    int durationMs, {
    int? width,
    int? height,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadedDurationMs = durationMs;
    return const VideoUploadResult(
      videoUrl: 'http://127.0.0.1:9600/uploads/video.mp4',
      thumbnailUrl: 'http://127.0.0.1:9600/uploads/thumb.jpg',
      durationMs: 1000,
      width: 320,
      height: 180,
      fileSize: 3,
    );
  }

  @override
  Future<FileUploadResult> uploadFile(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) async => const FileUploadResult(
    fileUrl: 'http://127.0.0.1:9600/uploads/a.pdf',
    fileName: 'a.pdf',
    fileSize: 3,
    fileType: 'pdf',
  );

  @override
  Future<String> downloadFile(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (failDownload) {
      throw StateError('download failed');
    }
    onProgress?.call(1, 2);
    onProgress?.call(2, 2);
    return savePath;
  }
}

class _FakeWsClient extends WsClient {
  _FakeWsClient()
    : _chatMessages = StreamController<ChatMessage>.broadcast(sync: true),
      _messageAcks = StreamController<MessageAck>.broadcast(sync: true),
      super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
        tokenProvider: () => null,
      );

  final StreamController<ChatMessage> _chatMessages;
  final StreamController<MessageAck> _messageAcks;
  final List<SendMessageRequest> sentRequests = [];

  @override
  Stream<ChatMessage> get chatMessageStream => _chatMessages.stream;

  @override
  Stream<MessageAck> get messageAckStream => _messageAcks.stream;

  @override
  void sendChatMessage(SendMessageRequest request) {
    sentRequests.add(request);
  }

  void emitMessage(ChatMessage message) {
    _chatMessages.add(message);
  }

  void emitAck(MessageAck ack) {
    _messageAcks.add(ack);
  }

  @override
  Future<void> dispose() async {
    await _chatMessages.close();
    await _messageAcks.close();
    await super.dispose();
  }
}
