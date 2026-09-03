class ReadStatusMember {
  const ReadStatusMember({
    required this.userId,
    required this.nickname,
    required this.avatar,
  });

  factory ReadStatusMember.fromJson(Map<String, dynamic> json) {
    return ReadStatusMember(
      userId: _requiredString(json, 'user_id'),
      nickname: _requiredString(json, 'nickname'),
      avatar: '${json['avatar'] ?? ''}',
    );
  }

  final String userId;
  final String nickname;
  final String avatar;
}

class MessageReadStatus {
  const MessageReadStatus({
    required this.messageId,
    required this.conversationId,
    required this.seq,
    required this.readMembers,
    required this.unreadMembers,
  });

  factory MessageReadStatus.fromJson(Map<String, dynamic> json) {
    return MessageReadStatus(
      messageId: _requiredString(json, 'message_id'),
      conversationId: _requiredString(json, 'conversation_id'),
      seq: _requiredInt(json, 'seq'),
      readMembers: _memberList(json, 'read_members'),
      unreadMembers: _memberList(json, 'unread_members'),
    );
  }

  final String messageId;
  final String conversationId;
  final int seq;
  final List<ReadStatusMember> readMembers;
  final List<ReadStatusMember> unreadMembers;
}

List<ReadStatusMember> _memberList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Read status field "$key" is not a list.');
  }
  return List<ReadStatusMember>.unmodifiable(
    value.map((item) {
      if (item is! Map) {
        throw FormatException('Read status field "$key" has an invalid item.');
      }
      return ReadStatusMember.fromJson(Map<String, dynamic>.from(item));
    }),
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = '${json[key] ?? ''}'.trim();
  if (value.isEmpty) {
    throw FormatException('Read status field "$key" is required.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null) {
    throw FormatException('Read status field "$key" is invalid.');
  }
  return parsed;
}
