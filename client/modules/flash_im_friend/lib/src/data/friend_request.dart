import 'package:equatable/equatable.dart';

import 'friend_user.dart';

enum FriendRequestDirection { received, sent }

class FriendRequest extends Equatable {
  const FriendRequest({
    required this.id,
    required this.fromUser,
    required this.message,
    required this.status,
    required this.createdAt,
    this.direction = FriendRequestDirection.received,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) =>
      FriendRequest.fromReceivedJson(json);

  factory FriendRequest.fromReceivedJson(Map<String, dynamic> json) {
    return FriendRequest._fromJson(
      json,
      userKey: 'from_user',
      direction: FriendRequestDirection.received,
    );
  }

  factory FriendRequest.fromSentJson(Map<String, dynamic> json) {
    return FriendRequest._fromJson(
      json,
      userKey: 'to_user',
      direction: FriendRequestDirection.sent,
    );
  }

  factory FriendRequest._fromJson(
    Map<String, dynamic> json, {
    required String userKey,
    required FriendRequestDirection direction,
  }) {
    final user = json[userKey];
    if (user is! Map) {
      throw FormatException('Friend request $userKey is required.');
    }
    return FriendRequest(
      id: _requiredString(json, 'id'),
      fromUser: FriendUser.fromJson(Map<String, dynamic>.from(user)),
      message: json['message'] is String ? json['message'] as String : '',
      status: json['status'] is String ? json['status'] as String : 'pending',
      createdAt: DateTime.parse(_requiredString(json, 'created_at')),
      direction: direction,
    );
  }

  final String id;
  final FriendUser fromUser;
  final String message;
  final String status;
  final DateTime createdAt;
  final FriendRequestDirection direction;

  FriendUser get otherUser => fromUser;
  bool get isReceived => direction == FriendRequestDirection.received;
  bool get isPending => status == 'pending';

  FriendRequest copyWith({String? status}) {
    return FriendRequest(
      id: id,
      fromUser: fromUser,
      message: message,
      status: status ?? this.status,
      createdAt: createdAt,
      direction: direction,
    );
  }

  @override
  List<Object?> get props => [
    id,
    fromUser,
    message,
    status,
    createdAt,
    direction,
  ];
}

class FriendAcceptResult extends Equatable {
  const FriendAcceptResult({
    required this.requestId,
    required this.friend,
    required this.conversationId,
  });

  factory FriendAcceptResult.fromJson(Map<String, dynamic> json) {
    final friend = json['friend'];
    if (friend is! Map) {
      throw const FormatException('Accept result friend is required.');
    }
    return FriendAcceptResult(
      requestId: _requiredString(json, 'request_id'),
      friend: FriendUser.fromJson(Map<String, dynamic>.from(friend)),
      conversationId: _requiredString(json, 'conversation_id'),
    );
  }

  final String requestId;
  final FriendUser friend;
  final String conversationId;

  @override
  List<Object?> get props => [requestId, friend, conversationId];
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Friend request field "$key" is required.');
}
