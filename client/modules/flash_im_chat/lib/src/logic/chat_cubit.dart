import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../data/message.dart';
import '../data/message_repository.dart';
import '../data/video_thumbnail_service.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required MessageRepository repository,
    required WsClient wsClient,
    required Conversation conversation,
    required String currentUserId,
    required VideoThumbnailService videoThumbnailService,
    String? currentUserName,
    String? currentUserAvatar,
    String Function(String value)? mediaUrlResolver,
    Future<Directory> Function()? downloadDirectoryProvider,
  }) : _repository = repository,
       _wsClient = wsClient,
       _conversation = conversation,
       _currentUserId = currentUserId,
       _currentUserName = currentUserName,
       _currentUserAvatar = currentUserAvatar,
       _videoThumbnailService = videoThumbnailService,
       _mediaUrlResolver = mediaUrlResolver ?? _identity,
       _downloadDirectoryProvider =
           downloadDirectoryProvider ?? getApplicationDocumentsDirectory,
       super(const ChatInitial()) {
    _chatMessageSubscription = _wsClient.chatMessageStream.listen(
      _handleIncomingMessage,
    );
    _messageAckSubscription = _wsClient.messageAckStream.listen(_handleAck);
  }

  static const _pageSize = 50;
  static const _ackTimeout = Duration(seconds: 12);

  final MessageRepository _repository;
  final WsClient _wsClient;
  final Conversation _conversation;
  final String _currentUserId;
  final String? _currentUserName;
  final String? _currentUserAvatar;
  final VideoThumbnailService _videoThumbnailService;
  final String Function(String value) _mediaUrlResolver;
  final Future<Directory> Function() _downloadDirectoryProvider;
  final Queue<String> _pendingLocalIds = Queue<String>();
  final Map<String, Timer> _ackTimers = {};
  StreamSubscription<ChatMessage>? _chatMessageSubscription;
  StreamSubscription<MessageAck>? _messageAckSubscription;

  Future<void> loadMessages() async {
    emit(const ChatLoading());
    try {
      final messages = await _repository.getMessages(
        conversationId: _conversation.id,
        limit: _pageSize,
      );
      emit(
        ChatLoaded(messages: messages, hasMore: messages.length == _pageSize),
      );
    } catch (_) {
      emit(const ChatError('消息加载失败，请稍后重试'));
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! ChatLoaded || current.isLoadingMore || !current.hasMore) {
      return;
    }
    final beforeSeq = current.messages
        .where((message) => message.seq > 0)
        .map((message) => message.seq)
        .fold<int?>(null, (min, seq) => min == null || seq < min ? seq : min);
    if (beforeSeq == null) return;

    emit(current.copyWith(isLoadingMore: true, errorMessage: null));
    try {
      final older = await _repository.getMessages(
        conversationId: _conversation.id,
        beforeSeq: beforeSeq,
        limit: _pageSize,
      );
      final latest = state;
      if (latest is! ChatLoaded) return;
      emit(
        latest.copyWith(
          messages: _sortMessages([...older, ...latest.messages]),
          hasMore: older.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      final latest = state;
      if (latest is ChatLoaded) {
        emit(latest.copyWith(isLoadingMore: false, errorMessage: '更多消息加载失败'));
      }
    }
  }

  void sendText(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty || state is! ChatLoaded) return;
    final local = _createLocal(content: trimmed);
    _appendLocal(local);
    _sendOverWebSocket(
      localId: local.id,
      content: trimmed,
      type: MessageType.text,
    );
  }

  Future<void> sendImageFromFile(String filePath) async {
    if (state is! ChatLoaded) return;
    final local = _createLocal(content: filePath, type: MessageType.image);
    _appendLocal(local);
    try {
      final result = await _repository.uploadImage(
        filePath,
        onProgress: _updateUploadProgress,
      );
      final extra = <String, dynamic>{
        'original_url': result.originalUrl,
        'thumbnail_url': result.thumbnailUrl,
        'width': result.width,
        'height': result.height,
        'size': result.size,
        'format': result.format,
      };
      _updateLocal(local.id, extra: extra, clearUploadProgress: true);
      _sendOverWebSocket(
        localId: local.id,
        content: result.originalUrl,
        type: MessageType.image,
        extra: extra,
      );
    } catch (_) {
      _markFailed(local.id, clearUploadProgress: true);
    }
  }

  Future<void> sendVideoFromFile(String filePath) async {
    if (state is! ChatLoaded) return;
    Message? local;
    try {
      final info = await _videoThumbnailService.extract(filePath);
      final initialExtra = <String, dynamic>{
        'local_video_path': filePath,
        'duration_ms': info.durationMs,
        'width': info.width,
        'height': info.height,
        'file_size': File(filePath).lengthSync(),
      };
      local = _createLocal(
        content: info.thumbnailPath,
        type: MessageType.video,
        extra: initialExtra,
      );
      _appendLocal(local);
      final result = await _repository.uploadVideo(
        filePath,
        info.thumbnailPath,
        info.durationMs,
        width: info.width,
        height: info.height,
        onProgress: _updateUploadProgress,
      );
      final extra = <String, dynamic>{
        ...initialExtra,
        'video_url': result.videoUrl,
        'thumbnail_url': result.thumbnailUrl,
        'duration_ms': result.durationMs,
        'width': result.width,
        'height': result.height,
        'file_size': result.fileSize,
      };
      _updateLocal(local.id, extra: extra, clearUploadProgress: true);
      _sendOverWebSocket(
        localId: local.id,
        content: result.videoUrl,
        type: MessageType.video,
        extra: _withoutLocalFields(extra),
      );
    } catch (_) {
      if (local != null) _markFailed(local.id, clearUploadProgress: true);
    }
  }

  Future<void> sendFileFromPicker(String filePath) async {
    if (state is! ChatLoaded) return;
    final fileName = _fileName(filePath);
    final local = _createLocal(
      content: fileName,
      type: MessageType.file,
      extra: {
        'file_name': fileName,
        'file_url': '',
        'file_type': _extension(fileName),
        'file_size': File(filePath).existsSync()
            ? File(filePath).lengthSync()
            : 0,
      },
    );
    _appendLocal(local);
    try {
      final result = await _repository.uploadFile(
        filePath,
        onProgress: _updateUploadProgress,
      );
      final extra = <String, dynamic>{
        'file_name': result.fileName,
        'file_url': result.fileUrl,
        'file_type': result.fileType,
        'file_size': result.fileSize,
      };
      _updateLocal(
        local.id,
        content: result.fileUrl,
        extra: extra,
        clearUploadProgress: true,
      );
      _sendOverWebSocket(
        localId: local.id,
        content: result.fileUrl,
        type: MessageType.file,
        extra: extra,
      );
    } catch (_) {
      _markFailed(local.id, clearUploadProgress: true);
    }
  }

  Future<void> downloadFile(
    String messageId,
    String fileUrl,
    String fileName,
  ) async {
    final current = state;
    if (current is! ChatLoaded) return;
    final directory = await _downloadDirectoryProvider();
    final downloads = Directory('${directory.path}/flash_im_downloads');
    await downloads.create(recursive: true);
    final savePath =
        '${downloads.path}/${DateTime.now().millisecondsSinceEpoch}_${_safeFileName(fileName)}';
    _updateDownload(
      messageId,
      const FileDownloadInfo(
        status: FileDownloadStatus.downloading,
        progress: 0,
      ),
    );
    try {
      final path = await _repository.downloadFile(
        fileUrl,
        savePath,
        onProgress: (received, total) {
          _updateDownload(
            messageId,
            FileDownloadInfo(
              status: FileDownloadStatus.downloading,
              progress: total > 0 ? (received / total).clamp(0, 1) : 0,
            ),
          );
        },
      );
      _updateDownload(
        messageId,
        FileDownloadInfo(
          status: FileDownloadStatus.done,
          progress: 1,
          localPath: path,
        ),
      );
    } catch (error) {
      _updateDownload(
        messageId,
        FileDownloadInfo(
          status: FileDownloadStatus.error,
          progress: 0,
          error: error.toString(),
        ),
      );
    }
  }

  FileDownloadInfo? getDownloadInfo(String messageId) {
    final current = state;
    return current is ChatLoaded ? current.fileDownloads[messageId] : null;
  }

  Message _createLocal({
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? extra,
  }) => Message.local(
    conversationId: _conversation.id,
    senderId: _currentUserId,
    senderName: _currentUserName?.trim().isNotEmpty == true
        ? _currentUserName!.trim()
        : '我',
    senderAvatar: _currentUserAvatar,
    content: content,
    type: type,
    extra: extra,
  );

  void _appendLocal(Message local) {
    final current = state;
    if (current is ChatLoaded) {
      emit(
        current.copyWith(messages: _sortMessages([...current.messages, local])),
      );
    }
  }

  void _sendOverWebSocket({
    required String localId,
    required String content,
    required MessageType type,
    Map<String, dynamic>? extra,
  }) {
    _pendingLocalIds.add(localId);
    _wsClient.sendMessage(
      conversationId: _conversation.id,
      content: content,
      type: Message.mapToProtoType(type),
      extra: extra == null ? null : utf8.encode(jsonEncode(extra)),
      clientId: localId,
    );
    _ackTimers[localId] = Timer(_ackTimeout, () => _markFailed(localId));
  }

  void _updateUploadProgress(int sent, int total) {
    final current = state;
    if (current is ChatLoaded && !isClosed) {
      emit(
        current.copyWith(
          uploadProgress: total > 0 ? (sent / total).clamp(0, 1) : 0,
        ),
      );
    }
  }

  void _updateLocal(
    String localId, {
    String? content,
    Map<String, dynamic>? extra,
    bool clearUploadProgress = false,
  }) {
    final current = state;
    if (current is! ChatLoaded || isClosed) return;
    emit(
      current.copyWith(
        messages: current.messages
            .map(
              (message) => message.id == localId
                  ? message.copyWith(content: content, extra: extra)
                  : message,
            )
            .toList(growable: false),
        uploadProgress: clearUploadProgress ? null : current.uploadProgress,
      ),
    );
  }

  void _updateDownload(String messageId, FileDownloadInfo info) {
    final current = state;
    if (current is! ChatLoaded || isClosed) return;
    emit(
      current.copyWith(
        fileDownloads: {...current.fileDownloads, messageId: info},
      ),
    );
  }

  void _handleAck(MessageAck ack) {
    final current = state;
    if (current is! ChatLoaded || _pendingLocalIds.isEmpty) return;
    final localId = _pendingLocalIds.removeFirst();
    _ackTimers.remove(localId)?.cancel();
    emit(
      current.copyWith(
        messages: _sortMessages(
          current.messages
              .map(
                (message) => message.id == localId
                    ? message.copyWith(
                        id: ack.messageId,
                        seq: ack.seq,
                        status: MessageStatus.sent,
                      )
                    : message,
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  void _handleIncomingMessage(ChatMessage message) {
    final current = state;
    if (current is! ChatLoaded ||
        message.conversationId != _conversation.id ||
        '${message.senderId}' == _currentUserId) {
      return;
    }
    var incoming = Message.fromChatMessage(message);
    incoming = _resolveMediaUrls(incoming);
    if (current.messages.any((item) => item.id == incoming.id)) return;
    emit(
      current.copyWith(
        messages: _sortMessages([...current.messages, incoming]),
      ),
    );
  }

  Message _resolveMediaUrls(Message message) {
    if (!message.isImage && !message.isVideo && !message.isFile) {
      return message;
    }
    final extra = message.extra == null
        ? null
        : Map<String, dynamic>.from(message.extra!);
    if (extra != null) {
      for (final key in [
        'thumbnail_url',
        'file_url',
        'video_url',
        'original_url',
      ]) {
        if (extra[key] != null) extra[key] = _mediaUrlResolver('${extra[key]}');
      }
    }
    return message.copyWith(
      content: _mediaUrlResolver(message.content),
      extra: extra,
    );
  }

  void _markFailed(String localId, {bool clearUploadProgress = false}) {
    final current = state;
    if (current is! ChatLoaded || isClosed) return;
    _pendingLocalIds.remove(localId);
    _ackTimers.remove(localId)?.cancel();
    emit(
      current.copyWith(
        messages: current.messages
            .map(
              (message) => message.id == localId
                  ? message.copyWith(status: MessageStatus.failed)
                  : message,
            )
            .toList(growable: false),
        uploadProgress: clearUploadProgress ? null : current.uploadProgress,
      ),
    );
  }

  List<Message> _sortMessages(List<Message> messages) {
    messages.sort((left, right) {
      if (left.seq == 0 && right.seq != 0) return 1;
      if (right.seq == 0 && left.seq != 0) return -1;
      if (left.seq != right.seq) return left.seq.compareTo(right.seq);
      return left.createdAt.compareTo(right.createdAt);
    });
    return messages;
  }

  @override
  Future<void> close() async {
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    await _chatMessageSubscription?.cancel();
    await _messageAckSubscription?.cancel();
    return super.close();
  }
}

String _identity(String value) => value;

Map<String, dynamic> _withoutLocalFields(Map<String, dynamic> value) {
  final copy = Map<String, dynamic>.from(value)..remove('local_video_path');
  return copy;
}

String _fileName(String path) => path.replaceAll('\\', '/').split('/').last;
String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? 'bin' : name.substring(dot + 1).toLowerCase();
}

String _safeFileName(String value) =>
    value.replaceAll(RegExp(r'[^a-zA-Z0-9._\-\u4e00-\u9fff]'), '_');
