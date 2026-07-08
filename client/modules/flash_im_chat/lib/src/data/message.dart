import 'package:equatable/equatable.dart';
import 'package:flash_im_core/flash_im_core.dart' as proto;

enum MessageStatus { sending, sent, failed }

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
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: _readString(json['id']),
      conversationId: _readString(json['conversation_id']),
      senderId: _readString(json['sender_id']),
      senderName: _readString(json['sender_name']),
      senderAvatar: json['sender_avatar'] as String?,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      content: _readString(json['content']),
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
      content: message.content,
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
  }) {
    final now = DateTime.now();
    return Message(
      id: 'local:${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      seq: 0,
      content: content,
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
  final String content;
  final MessageStatus status;
  final DateTime createdAt;

  Message copyWith({
    String? id,
    int? seq,
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
      content: content,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    senderName,
    senderAvatar,
    seq,
    content,
    status,
    createdAt,
  ];
}

String _readString(dynamic value) => value?.toString() ?? '';

DateTime _parseDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.parse(value).toLocal();
  }
  return DateTime.now();
}
