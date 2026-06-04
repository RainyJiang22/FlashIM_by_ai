class ChatRoomSocketFrame {
  const ChatRoomSocketFrame({
    required this.type,
    this.message,
    this.userId,
    this.nickname,
    this.avatar,
    this.text,
    this.messageId,
    this.sentAt,
  });

  final String type;
  final String? message;
  final int? userId;
  final String? nickname;
  final String? avatar;
  final String? text;
  final int? messageId;
  final int? sentAt;

  factory ChatRoomSocketFrame.fromJson(Map<String, dynamic> json) {
    return ChatRoomSocketFrame(
      type: json['type'] as String? ?? '',
      message: json['message'] as String?,
      userId: (json['user_id'] as num?)?.toInt(),
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      text: json['text'] as String?,
      messageId: (json['message_id'] as num?)?.toInt(),
      sentAt: (json['sent_at'] as num?)?.toInt(),
    );
  }
}
