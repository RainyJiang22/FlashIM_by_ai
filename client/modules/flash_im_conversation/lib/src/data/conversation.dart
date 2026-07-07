import 'package:equatable/equatable.dart';

class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.type,
    required this.unreadCount,
    required this.createdAt,
    this.name,
    this.peerUserId,
    this.peerNickname,
    this.peerAvatar,
    this.lastMessageAt,
    this.lastMessagePreview,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: _readRequiredString(json, 'id'),
      type: (json['type'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      peerUserId: json['peer_user_id']?.toString(),
      peerNickname: json['peer_nickname'] as String?,
      peerAvatar: json['peer_avatar'] as String?,
      lastMessageAt: _parseNullableDateTime(json['last_message_at']),
      lastMessagePreview: json['last_message_preview'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      createdAt: _parseRequiredDateTime(json['created_at'], 'created_at'),
    );
  }

  final String id;
  final int type;
  final String? name;
  final String? peerUserId;
  final String? peerNickname;
  final String? peerAvatar;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    peerUserId,
    peerNickname,
    peerAvatar,
    lastMessageAt,
    lastMessagePreview,
    unreadCount,
    createdAt,
  ];
}

extension ConversationDisplay on Conversation {
  bool get isPrivateChat => type == 0;

  String get displayName {
    if (isPrivateChat) {
      final nickname = peerNickname?.trim();
      if (nickname != null && nickname.isNotEmpty) {
        return nickname;
      }
      final userId = peerUserId?.trim();
      if (userId != null && userId.isNotEmpty) {
        return '用户 $userId';
      }
    }

    final groupName = name?.trim();
    if (groupName != null && groupName.isNotEmpty) {
      return groupName;
    }

    return '未知会话';
  }

  String get displayPreview {
    final preview = lastMessagePreview?.trim();
    if (preview != null && preview.isNotEmpty) {
      return preview;
    }
    return '暂无消息';
  }

  DateTime get displayTime => lastMessageAt ?? createdAt;

  String get avatarSeed {
    final avatar = peerAvatar?.trim();
    if (avatar != null && avatar.isNotEmpty) {
      return avatar;
    }
    final userId = peerUserId?.trim();
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }
    return name?.trim().isNotEmpty == true ? name!.trim() : id;
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Conversation field "$key" is required.');
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.parse(value);
  }
  throw const FormatException('Conversation date field is invalid.');
}

DateTime _parseRequiredDateTime(dynamic value, String key) {
  final parsed = _parseNullableDateTime(value);
  if (parsed == null) {
    throw FormatException('Conversation field "$key" is required.');
  }
  return parsed;
}
