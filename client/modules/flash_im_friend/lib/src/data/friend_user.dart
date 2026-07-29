import 'package:equatable/equatable.dart';

class FriendUser extends Equatable {
  const FriendUser({
    required this.accountId,
    required this.nickname,
    required this.avatar,
    required this.signature,
    this.flashId,
    this.relationStatus,
    this.createdAt,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      accountId: _requiredInt(json, 'account_id'),
      nickname: _string(json['nickname']),
      avatar: _string(json['avatar']),
      signature: _string(json['signature']),
      flashId: _nullableString(json['flash_id']),
      relationStatus: _nullableString(json['relation_status']),
      createdAt: _nullableDateTime(json['created_at']),
    );
  }

  final int accountId;
  final String nickname;
  final String avatar;
  final String signature;
  final String? flashId;
  final String? relationStatus;
  final DateTime? createdAt;

  bool get isFriend => relationStatus == 'friend';
  bool get isPendingSent => relationStatus == 'pending_sent';
  bool get isPendingReceived => relationStatus == 'pending_received';

  String get displayName {
    final value = nickname.trim();
    return value.isEmpty ? '用户 $accountId' : value;
  }

  FriendUser copyWith({String? relationStatus}) {
    return FriendUser(
      accountId: accountId,
      nickname: nickname,
      avatar: avatar,
      signature: signature,
      flashId: flashId,
      relationStatus: relationStatus ?? this.relationStatus,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    accountId,
    nickname,
    avatar,
    signature,
    flashId,
    relationStatus,
    createdAt,
  ];
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  throw FormatException('FriendUser field "$key" is required.');
}

String _string(dynamic value) => value is String ? value : '';

String? _nullableString(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value;
}

DateTime? _nullableDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.parse(value);
  }
  throw const FormatException('FriendUser created_at is invalid.');
}
