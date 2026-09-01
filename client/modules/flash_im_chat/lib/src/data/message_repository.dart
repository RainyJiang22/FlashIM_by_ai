import 'package:dio/dio.dart';

import 'message.dart';

typedef TransferProgress = void Function(int current, int total);

abstract interface class MessageRepository {
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  });

  Future<ImageUploadResult> uploadImage(
    String filePath, {
    TransferProgress? onProgress,
  });

  Future<VideoUploadResult> uploadVideo(
    String videoPath,
    String thumbPath,
    int durationMs, {
    int? width,
    int? height,
    TransferProgress? onProgress,
  });

  Future<FileUploadResult> uploadFile(
    String filePath, {
    TransferProgress? onProgress,
  });

  Future<String> downloadFile(
    String url,
    String savePath, {
    TransferProgress? onProgress,
  });
}

class ImageUploadResult {
  const ImageUploadResult({
    required this.originalUrl,
    required this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.size,
    required this.format,
  });

  factory ImageUploadResult.fromJson(Map<String, dynamic> json) =>
      ImageUploadResult(
        originalUrl: '${json['original_url'] ?? ''}',
        thumbnailUrl: '${json['thumbnail_url'] ?? ''}',
        width: _int(json['width']),
        height: _int(json['height']),
        size: _int(json['size']),
        format: '${json['format'] ?? ''}',
      );

  final String originalUrl;
  final String thumbnailUrl;
  final int width;
  final int height;
  final int size;
  final String format;
}

class VideoUploadResult {
  const VideoUploadResult({
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.fileSize,
  });

  factory VideoUploadResult.fromJson(Map<String, dynamic> json) =>
      VideoUploadResult(
        videoUrl: '${json['video_url'] ?? ''}',
        thumbnailUrl: '${json['thumbnail_url'] ?? ''}',
        durationMs: _int(json['duration_ms']),
        width: _int(json['width']),
        height: _int(json['height']),
        fileSize: _int(json['file_size']),
      );

  final String videoUrl;
  final String thumbnailUrl;
  final int durationMs;
  final int width;
  final int height;
  final int fileSize;
}

class FileUploadResult {
  const FileUploadResult({
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
  });

  factory FileUploadResult.fromJson(Map<String, dynamic> json) =>
      FileUploadResult(
        fileUrl: '${json['file_url'] ?? ''}',
        fileName: '${json['file_name'] ?? ''}',
        fileSize: _int(json['file_size']),
        fileType: '${json['file_type'] ?? ''}',
      );

  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String fileType;
}

class DioMessageRepository implements MessageRepository {
  DioMessageRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  String resolveMediaUrl(String url) {
    final parsed = Uri.tryParse(url);
    if (url.isEmpty || parsed?.hasScheme == true) return url;
    return Uri.parse(_dio.options.baseUrl).resolve(url).toString();
  }

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  }) async {
    final queryParameters = <String, dynamic>{'limit': limit};
    if (beforeSeq != null) queryParameters['before_seq'] = beforeSeq;

    final response = await _dio.get<dynamic>(
      '/conversations/$conversationId/messages',
      queryParameters: queryParameters,
    );
    final payload = response.data;
    if (payload is! List) {
      throw const FormatException('Message payload is not a list.');
    }

    final messages = payload.map((dynamic item) {
      if (item is! Map) {
        throw const FormatException('Message item is not a JSON object.');
      }
      final json = Map<String, dynamic>.from(item);
      _normalizePayloadUrls(json);
      return Message.fromJson(json);
    }).toList();
    messages.sort(_compareMessagesAscending);
    return messages;
  }

  @override
  Future<ImageUploadResult> uploadImage(
    String filePath, {
    TransferProgress? onProgress,
  }) async {
    final response = await _dio.post<dynamic>(
      '/api/upload/image',
      data: FormData.fromMap({'file': await MultipartFile.fromFile(filePath)}),
      onSendProgress: onProgress,
    );
    final result = ImageUploadResult.fromJson(_json(response.data));
    return ImageUploadResult(
      originalUrl: resolveMediaUrl(result.originalUrl),
      thumbnailUrl: resolveMediaUrl(result.thumbnailUrl),
      width: result.width,
      height: result.height,
      size: result.size,
      format: result.format,
    );
  }

  @override
  Future<VideoUploadResult> uploadVideo(
    String videoPath,
    String thumbPath,
    int durationMs, {
    int? width,
    int? height,
    TransferProgress? onProgress,
  }) async {
    final response = await _dio.post<dynamic>(
      '/api/upload/video',
      data: FormData.fromMap({
        'video': await MultipartFile.fromFile(videoPath),
        'thumbnail': await MultipartFile.fromFile(thumbPath),
        'duration_ms': durationMs,
        'width': width ?? 0,
        'height': height ?? 0,
      }),
      onSendProgress: onProgress,
    );
    final result = VideoUploadResult.fromJson(_json(response.data));
    return VideoUploadResult(
      videoUrl: resolveMediaUrl(result.videoUrl),
      thumbnailUrl: resolveMediaUrl(result.thumbnailUrl),
      durationMs: result.durationMs,
      width: result.width,
      height: result.height,
      fileSize: result.fileSize,
    );
  }

  @override
  Future<FileUploadResult> uploadFile(
    String filePath, {
    TransferProgress? onProgress,
  }) async {
    final response = await _dio.post<dynamic>(
      '/api/upload/file',
      data: FormData.fromMap({'file': await MultipartFile.fromFile(filePath)}),
      onSendProgress: onProgress,
    );
    final result = FileUploadResult.fromJson(_json(response.data));
    return FileUploadResult(
      fileUrl: resolveMediaUrl(result.fileUrl),
      fileName: result.fileName,
      fileSize: result.fileSize,
      fileType: result.fileType,
    );
  }

  @override
  Future<String> downloadFile(
    String url,
    String savePath, {
    TransferProgress? onProgress,
  }) async {
    await _dio.download(
      resolveMediaUrl(url),
      savePath,
      onReceiveProgress: onProgress,
    );
    return savePath;
  }

  void _normalizePayloadUrls(Map<String, dynamic> payload) {
    final type = _int(payload['msg_type'] ?? payload['type']);
    if (type < 1 || type > 3) return;
    payload['content'] = resolveMediaUrl('${payload['content'] ?? ''}');
    final extra = Message.parseExtra(payload['extra']);
    if (extra == null) return;
    for (final key in [
      'thumbnail_url',
      'file_url',
      'video_url',
      'original_url',
    ]) {
      if (extra[key] != null) extra[key] = resolveMediaUrl('${extra[key]}');
    }
    payload['extra'] = extra;
  }
}

Map<String, dynamic> _json(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Upload payload is not a JSON object.');
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

int _compareMessagesAscending(Message left, Message right) {
  if (left.seq != right.seq) return left.seq.compareTo(right.seq);
  return left.createdAt.compareTo(right.createdAt);
}
