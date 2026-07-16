import 'package:equatable/equatable.dart';

import '../data/message.dart';

enum FileDownloadStatus { idle, downloading, done, error }

class FileDownloadInfo extends Equatable {
  const FileDownloadInfo({
    required this.status,
    required this.progress,
    this.localPath,
    this.error,
  });

  const FileDownloadInfo.idle()
    : status = FileDownloadStatus.idle,
      progress = 0,
      localPath = null,
      error = null;

  final FileDownloadStatus status;
  final double progress;
  final String? localPath;
  final String? error;

  @override
  List<Object?> get props => [status, progress, localPath, error];
}

sealed class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => const [];
}

final class ChatInitial extends ChatState {
  const ChatInitial();
}

final class ChatLoading extends ChatState {
  const ChatLoading();
}

final class ChatLoaded extends ChatState {
  const ChatLoaded({
    required this.messages,
    required this.hasMore,
    this.isLoadingMore = false,
    this.errorMessage,
    this.uploadProgress,
    this.fileDownloads = const {},
  });

  final List<Message> messages;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;
  final double? uploadProgress;
  final Map<String, FileDownloadInfo> fileDownloads;

  ChatLoaded copyWith({
    List<Message>? messages,
    bool? hasMore,
    bool? isLoadingMore,
    Object? errorMessage = _unset,
    Object? uploadProgress = _unset,
    Map<String, FileDownloadInfo>? fileDownloads,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      uploadProgress: identical(uploadProgress, _unset)
          ? this.uploadProgress
          : uploadProgress as double?,
      fileDownloads: fileDownloads ?? this.fileDownloads,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    hasMore,
    isLoadingMore,
    errorMessage,
    uploadProgress,
    fileDownloads,
  ];
}

final class ChatError extends ChatState {
  const ChatError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

const Object _unset = Object();
