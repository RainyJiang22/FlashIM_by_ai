import 'package:equatable/equatable.dart';

import 'friend_user.dart';

class FriendRequest extends Equatable {
  const FriendRequest({
    required this.id,
    required this.fromUser,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final user = json['from_user'];
    if (user is! Map) {
      throw const FormatException('Friend request from_user is required.');
    }
    return FriendRequest(
      id: _requiredString(json, 'id'),
      fromUser: FriendUser.fromJson(Map<String, dynamic>.from(user)),
      message: json['message'] is String ? json['message'] as String : '',
      status: json['status'] is String ? json['status'] as String : 'pending',
      createdAt: DateTime.parse(_requiredString(json, 'created_at')),
    );
  }

  final String id;
  final FriendUser fromUser;
  final String message;
  final String status;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, fromUser, message, status, createdAt];
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
