import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flash_im_core/flash_im_core.dart' as proto;

enum MessageStatus { sending, sent, failed }

enum MessageType { text, image, video, file, groupInvitation, groupCreated }

class GroupInvitationExtra extends Equatable {
  const GroupInvitationExtra({
    required this.invitationId,
    required this.groupId,
    required this.groupName,
    required this.inviterName,
  });

  factory GroupInvitationExtra.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      throw FormatException('Group invitation field "$key" is required.');
    }

    return GroupInvitationExtra(
      invitationId: requiredString('invitation_id'),
      groupId: requiredString('group_id'),
      groupName: requiredString('group_name'),
      inviterName: requiredString('inviter_name'),
    );
  }

  final String invitationId;
  final String groupId;
  final String groupName;
  final String inviterName;

  @override
  List<Object?> get props => [invitationId, groupId, groupName, inviterName];
}

class VideoExtra extends Equatable {
  const VideoExtra({
    required this.thumbnailUrl,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.fileSize,
  });

  factory VideoExtra.fromJson(Map<String, dynamic> json) => VideoExtra(
    thumbnailUrl: _readString(json['thumbnail_url']),
    durationMs: _readInt(json['duration_ms']),
    width: _readInt(json['width']),
    height: _readInt(json['height']),
    fileSize: _readInt(json['file_size']),
  );

  final String thumbnailUrl;
  final int durationMs;
  final int width;
  final int height;
  final int fileSize;

  String get formattedDuration {
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
    thumbnailUrl,
    durationMs,
    width,
    height,
    fileSize,
  ];
}

class FileExtra extends Equatable {
  const FileExtra({
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
  });

  factory FileExtra.fromJson(Map<String, dynamic> json) => FileExtra(
    fileName: _readString(json['file_name']),
    fileUrl: _readString(json['file_url']),
    fileType: _readString(json['file_type']),
    fileSize: _readInt(json['file_size']),
  );

  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;

  String get formattedSize => formatFileSize(fileSize);

  @override
  List<Object?> get props => [fileName, fileUrl, fileType, fileSize];
}

class Message extends Equatable {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.seq,
    required this.content,
    required this.status,
    required this.createdAt,
    this.senderAvatar,
    this.type = MessageType.text,
    this.extra,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: _readString(json['id']),
      conversationId: _readString(json['conversation_id']),
      senderId: _readString(json['sender_id']),
      senderName: _readString(json['sender_name']),
      senderAvatar: json['sender_avatar'] as String?,
      seq: _readInt(json['seq']),
      type: mapProtoType(_readInt(json['msg_type'] ?? json['type'])),
      content: _readString(json['content']),
      extra: parseExtra(json['extra']),
      status: MessageStatus.sent,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  factory Message.fromChatMessage(proto.ChatMessage message) {
    return Message(
      id: message.id,
      conversationId: message.conversationId,
      senderId: '${message.senderId}',
      senderName: message.senderName,
      senderAvatar: message.senderAvatar.isEmpty ? null : message.senderAvatar,
      seq: message.seq,
      type: mapProtoType(message.type),
      content: message.content,
      extra: parseExtra(message.extra),
      status: MessageStatus.sent,
      createdAt:
          DateTime.tryParse(message.createdAt)?.toLocal() ?? DateTime.now(),
    );
  }

  factory Message.local({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    String? senderAvatar,
    MessageType type = MessageType.text,
    Map<String, dynamic>? extra,
  }) {
    final now = DateTime.now();
    return Message(
      id: 'local:${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      seq: 0,
      type: type,
      content: content,
      extra: extra,
      status: MessageStatus.sending,
      createdAt: now,
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final int seq;
  final MessageType type;
  final String content;
  final Map<String, dynamic>? extra;
  final MessageStatus status;
  final DateTime createdAt;

  bool get isImage => type == MessageType.image;
  bool get isVideo => type == MessageType.video;
  bool get isFile => type == MessageType.file;
  bool get isGroupInvitation => type == MessageType.groupInvitation;
  bool get isGroupCreated => type == MessageType.groupCreated;
  VideoExtra? get videoExtra =>
      isVideo && extra != null ? VideoExtra.fromJson(extra!) : null;
  FileExtra? get fileExtra =>
      isFile && extra != null ? FileExtra.fromJson(extra!) : null;
  GroupInvitationExtra? get groupInvitationExtra {
    if (!isGroupInvitation || extra == null) return null;
    try {
      return GroupInvitationExtra.fromJson(extra!);
    } on FormatException {
      return null;
    }
  }

  Message copyWith({
    String? id,
    int? seq,
    MessageType? type,
    String? content,
    Object? extra = _unset,
    MessageStatus? status,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      seq: seq ?? this.seq,
      type: type ?? this.type,
      content: content ?? this.content,
      extra: identical(extra, _unset)
          ? this.extra
          : extra as Map<String, dynamic>?,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static MessageType mapProtoType(int value) => switch (value) {
    1 => MessageType.image,
    2 => MessageType.video,
    3 => MessageType.file,
    4 => MessageType.groupInvitation,
    5 => MessageType.groupCreated,
    _ => MessageType.text,
  };

  static int mapToProtoType(MessageType type) => switch (type) {
    MessageType.text => 0,
    MessageType.image => 1,
    MessageType.video => 2,
    MessageType.file => 3,
    MessageType.groupInvitation => 4,
    MessageType.groupCreated => 5,
  };

  static Map<String, dynamic>? parseExtra(dynamic value) {
    if (value == null || value == '') return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    senderName,
    senderAvatar,
    seq,
    type,
    content,
    extra,
    status,
    createdAt,
  ];
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _readString(dynamic value) => value?.toString() ?? '';
int _readInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

DateTime _parseDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.parse(value).toLocal();
  }
  return DateTime.now();
}

const Object _unset = Object();
