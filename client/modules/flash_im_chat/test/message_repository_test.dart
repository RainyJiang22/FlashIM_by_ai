import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DioMessageRepository fetches messages with before_seq', () async {
    final adapter = _FakeAdapter({
      '/conversations/c1/messages': [
        {
          'id': 'm2',
          'conversation_id': 'c1',
          'sender_id': 2,
          'seq': 2,
          'msg_type': 1,
          'content': '/uploads/original/second.jpg',
          'extra': {'thumbnail_url': '/uploads/thumb/second.webp'},
          'created_at': '2026-04-02T09:02:00Z',
        },
        {
          'id': 'm1',
          'conversation_id': 'c1',
          'sender_id': 1,
          'seq': 1,
          'msg_type': 0,
          'content': 'first',
          'created_at': '2026-04-02T09:01:00Z',
        },
      ],
    });
    final repository = DioMessageRepository(dio: _dio(adapter));

    final messages = await repository.getMessages(
      conversationId: 'c1',
      beforeSeq: 9,
      limit: 20,
    );

    expect(adapter.requests.single.path, '/conversations/c1/messages');
    expect(adapter.requests.single.queryParameters, {
      'limit': 20,
      'before_seq': 9,
    });
    expect(messages.map((message) => message.id), ['m1', 'm2']);
    expect(
      messages.last.content,
      'http://127.0.0.1:9600/uploads/original/second.jpg',
    );
  });

  test('history keeps group system message content unchanged', () async {
    final adapter = _FakeAdapter({
      '/conversations/group-1/messages': [
        {
          'id': 'system-1',
          'conversation_id': 'group-1',
          'sender_id': 2,
          'sender_name': '系统助手',
          'seq': 1,
          'msg_type': 5,
          'content': '系统助手 邀请 花青 进群',
          'extra': {'system_event': 'member_invited'},
          'created_at': '2026-09-01T09:02:00Z',
        },
      ],
    });
    final repository = DioMessageRepository(dio: _dio(adapter));

    final messages = await repository.getMessages(conversationId: 'group-1');

    expect(messages.single.content, '系统助手 邀请 花青 进群');
    expect(messages.single.extra?['system_event'], 'member_invited');
  });

  test(
    'upload methods send expected multipart fields and parse results',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'flash_im_upload_test',
      );
      addTearDown(() => temp.delete(recursive: true));
      final image = File('${temp.path}/photo.jpg')..writeAsBytesSync([1]);
      final video = File('${temp.path}/clip.mp4')..writeAsBytesSync([1, 2]);
      final thumb = File('${temp.path}/thumb.jpg')..writeAsBytesSync([3]);
      final file = File('${temp.path}/doc.pdf')..writeAsBytesSync([4]);
      final adapter = _FakeAdapter({
        '/api/upload/image': {
          'original_url': '/uploads/original/a.jpg',
          'thumbnail_url': '/uploads/thumb/a.webp',
          'width': 640,
          'height': 480,
          'size': 1,
          'format': 'jpg',
        },
        '/api/upload/video': {
          'video_url': '/uploads/video/a.mp4',
          'thumbnail_url': '/uploads/thumb/a.jpg',
          'duration_ms': 1200,
          'width': 320,
          'height': 180,
          'file_size': 2,
        },
        '/api/upload/file': {
          'file_url': '/uploads/file/a.pdf',
          'file_name': 'doc.pdf',
          'file_size': 1,
          'file_type': 'pdf',
        },
      });
      final repository = DioMessageRepository(dio: _dio(adapter));

      final imageResult = await repository.uploadImage(image.path);
      final videoResult = await repository.uploadVideo(
        video.path,
        thumb.path,
        1200,
        width: 320,
        height: 180,
      );
      final fileResult = await repository.uploadFile(file.path);

      expect(
        imageResult.originalUrl,
        'http://127.0.0.1:9600/uploads/original/a.jpg',
      );
      expect(videoResult.durationMs, 1200);
      expect(fileResult.fileName, 'doc.pdf');

      final imageForm = adapter.requests[0].data as FormData;
      final videoForm = adapter.requests[1].data as FormData;
      final fileForm = adapter.requests[2].data as FormData;
      expect(imageForm.files.map((entry) => entry.key), ['file']);
      expect(videoForm.files.map((entry) => entry.key), ['video', 'thumbnail']);
      expect(
        videoForm.fields.map((entry) => entry.key),
        containsAll(['duration_ms', 'width', 'height']),
      );
      expect(fileForm.files.map((entry) => entry.key), ['file']);
    },
  );

  test('downloadFile resolves URL and writes response to save path', () async {
    final temp = await Directory.systemTemp.createTemp(
      'flash_im_download_test',
    );
    addTearDown(() => temp.delete(recursive: true));
    final adapter = _FakeAdapter({
      '/uploads/file/a.pdf': [1, 2, 3],
    });
    final repository = DioMessageRepository(dio: _dio(adapter));
    final savePath = '${temp.path}/a.pdf';

    final result = await repository.downloadFile(
      '/uploads/file/a.pdf',
      savePath,
    );

    expect(result, savePath);
    expect(File(savePath).readAsBytesSync(), [1, 2, 3]);
    expect(
      adapter.requests.single.path,
      'http://127.0.0.1:9600/uploads/file/a.pdf',
    );
  });
}

Dio _dio(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9600'));
  dio.httpClientAdapter = adapter;
  return dio;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, dynamic> responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = responses[Uri.parse(options.path).path];
    if (options.responseType == ResponseType.bytes ||
        options.responseType == ResponseType.stream) {
      return ResponseBody.fromBytes(List<int>.from(response as List), 200);
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
