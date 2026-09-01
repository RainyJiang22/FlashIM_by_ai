import 'package:equatable/equatable.dart';
import 'package:flash_shared/flash_shared.dart';

class Conversation extends Equatable {
  Conversation({
    required this.id,
    required this.type,
    required this.unreadCount,
    required this.createdAt,
    this.name,
    this.avatar,
    this.ownerId,
    List<String> memberAvatars = const <String>[],
    this.peerUserId,
    this.peerNickname,
    this.peerAvatar,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.announcement = '',
    this.isDissolved = false,
  }) : memberAvatars = List<String>.unmodifiable(memberAvatars);

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final memberAvatars = _parseStringList(json['member_avatars']);
    final rawAvatar = json['avatar'] as String?;
    return Conversation(
      id: _readRequiredString(json, 'id'),
      type: (json['type'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      avatar: rawAvatar?.trim().isNotEmpty == true
          ? rawAvatar
          : memberAvatars.isEmpty
          ? null
          : encodeGroupAvatar(memberAvatars),
      ownerId: json['owner_id']?.toString(),
      memberAvatars: memberAvatars,
      peerUserId: json['peer_user_id']?.toString(),
      peerNickname: json['peer_nickname'] as String?,
      peerAvatar: json['peer_avatar'] as String?,
      lastMessageAt: _parseNullableDateTime(json['last_message_at']),
      lastMessagePreview: json['last_message_preview'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      announcement: json['announcement']?.toString() ?? '',
      isDissolved: json['is_dissolved'] == true,
      createdAt: _parseRequiredDateTime(json['created_at'], 'created_at'),
    );
  }

  factory Conversation.placeholder({
    required String id,
    required String lastMessagePreview,
    required DateTime lastMessageAt,
    required int unreadCount,
  }) {
    return Conversation(
      id: id,
      type: 0,
      unreadCount: unreadCount,
      createdAt: lastMessageAt,
      lastMessageAt: lastMessageAt,
      lastMessagePreview: lastMessagePreview,
    );
  }

  final String id;
  final int type;
  final String? name;
  final String? avatar;
  final String? ownerId;
  final List<String> memberAvatars;
  final String? peerUserId;
  final String? peerNickname;
  final String? peerAvatar;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final String announcement;
  final bool isDissolved;
  final DateTime createdAt;

  Conversation copyWith({
    int? type,
    String? name,
    String? avatar,
    String? ownerId,
    List<String>? memberAvatars,
    int? unreadCount,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    String? peerNickname,
    String? peerAvatar,
    String? announcement,
    bool? isDissolved,
  }) {
    return Conversation(
      id: id,
      type: type ?? this.type,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      ownerId: ownerId ?? this.ownerId,
      memberAvatars: memberAvatars ?? this.memberAvatars,
      peerUserId: peerUserId,
      peerNickname: peerNickname ?? this.peerNickname,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      announcement: announcement ?? this.announcement,
      isDissolved: isDissolved ?? this.isDissolved,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    avatar,
    ownerId,
    memberAvatars,
    peerUserId,
    peerNickname,
    peerAvatar,
    lastMessageAt,
    lastMessagePreview,
    unreadCount,
    announcement,
    isDissolved,
    createdAt,
  ];
}

extension ConversationDisplay on Conversation {
  bool get isPrivateChat => type == 0;

  bool get isGroupChat => type == 1;

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
    final userId = peerUserId?.trim();
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }
    return name?.trim().isNotEmpty == true ? name!.trim() : id;
  }

  String? get groupAvatar {
    final value = avatar?.trim();
    if (value != null && value.isNotEmpty) return value;
    return memberAvatars.isEmpty ? null : encodeGroupAvatar(memberAvatars);
  }
}

List<String> _parseStringList(dynamic value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is! List) {
    throw const FormatException(
      'Conversation field "member_avatars" is not a list.',
    );
  }
  return List<String>.unmodifiable(
    value.whereType<String>().where((item) => item.trim().isNotEmpty),
  );
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
