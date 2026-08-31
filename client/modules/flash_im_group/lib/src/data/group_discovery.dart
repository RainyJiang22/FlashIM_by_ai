import 'package:equatable/equatable.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';

class GroupSearchItem extends Equatable {
  const GroupSearchItem({
    required this.conversationId,
    required this.groupNumber,
    required this.name,
    required this.avatar,
    required this.memberCount,
    required this.joinApprovalRequired,
    required this.isMember,
    required this.hasPendingRequest,
  });

  factory GroupSearchItem.fromJson(Map<String, dynamic> json) =>
      GroupSearchItem(
        conversationId: _requiredString(json, 'conversation_id'),
        groupNumber: _requiredString(json, 'group_number'),
        name: _requiredString(json, 'name'),
        avatar: _string(json['avatar']),
        memberCount: _requiredInt(json, 'member_count'),
        joinApprovalRequired: json['join_approval_required'] == true,
        isMember: json['is_member'] == true,
        hasPendingRequest: json['has_pending_request'] == true,
      );

  final String conversationId;
  final String groupNumber;
  final String name;
  final String avatar;
  final int memberCount;
  final bool joinApprovalRequired;
  final bool isMember;
  final bool hasPendingRequest;

  GroupSearchItem copyWith({bool? isMember, bool? hasPendingRequest}) =>
      GroupSearchItem(
        conversationId: conversationId,
        groupNumber: groupNumber,
        name: name,
        avatar: avatar,
        memberCount: memberCount,
        joinApprovalRequired: joinApprovalRequired,
        isMember: isMember ?? this.isMember,
        hasPendingRequest: hasPendingRequest ?? this.hasPendingRequest,
      );

  @override
  List<Object?> get props => [
    conversationId,
    groupNumber,
    name,
    avatar,
    memberCount,
    joinApprovalRequired,
    isMember,
    hasPendingRequest,
  ];
}

class JoinGroupResult extends Equatable {
  const JoinGroupResult({
    required this.autoApproved,
    this.requestId,
    this.conversation,
  });

  factory JoinGroupResult.fromJson(Map<String, dynamic> json) {
    final rawConversation = json['conversation'];
    return JoinGroupResult(
      autoApproved: json['auto_approved'] == true,
      requestId: _nullableString(json['request_id']),
      conversation: rawConversation is Map
          ? Conversation.fromJson(Map<String, dynamic>.from(rawConversation))
          : null,
    );
  }

  final bool autoApproved;
  final String? requestId;
  final Conversation? conversation;

  @override
  List<Object?> get props => [autoApproved, requestId, conversation];
}

enum GroupJoinRequestStatus { pending, approved, rejected }

class GroupJoinRequest extends Equatable {
  const GroupJoinRequest({
    required this.id,
    required this.conversationId,
    required this.groupName,
    required this.groupAvatar,
    required this.applicantId,
    required this.applicantName,
    required this.applicantAvatar,
    required this.message,
    required this.status,
    required this.createdAt,
    this.handledAt,
  });

  factory GroupJoinRequest.fromJson(Map<String, dynamic> json) =>
      GroupJoinRequest(
        id: _requiredString(json, 'id'),
        conversationId: _requiredString(json, 'conversation_id'),
        groupName: _requiredString(json, 'group_name'),
        groupAvatar: _string(json['group_avatar']),
        applicantId: _requiredInt(json, 'applicant_id'),
        applicantName: _requiredString(json, 'applicant_name'),
        applicantAvatar: _string(json['applicant_avatar']),
        message: _requiredString(json, 'message'),
        status: _statusFromString(_requiredString(json, 'status')),
        createdAt: _requiredDateTime(json, 'created_at'),
        handledAt: _nullableDateTime(json['handled_at']),
      );

  factory GroupJoinRequest.fromNotification(
    GroupJoinRequestNotification event,
  ) => GroupJoinRequest(
    id: event.requestId,
    conversationId: event.conversationId,
    groupName: event.groupName,
    groupAvatar: event.groupAvatar,
    applicantId: event.applicantId.toInt(),
    applicantName: event.applicantName,
    applicantAvatar: event.applicantAvatar,
    message: event.message,
    status: switch (event.status) {
      1 => GroupJoinRequestStatus.approved,
      2 => GroupJoinRequestStatus.rejected,
      _ => GroupJoinRequestStatus.pending,
    },
    createdAt: DateTime.tryParse(event.createdAt)?.toLocal() ?? DateTime.now(),
    handledAt: event.handledAt.isEmpty
        ? null
        : DateTime.tryParse(event.handledAt)?.toLocal(),
  );

  final String id;
  final String conversationId;
  final String groupName;
  final String groupAvatar;
  final int applicantId;
  final String applicantName;
  final String applicantAvatar;
  final String message;
  final GroupJoinRequestStatus status;
  final DateTime createdAt;
  final DateTime? handledAt;

  bool get isPending => status == GroupJoinRequestStatus.pending;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    groupName,
    groupAvatar,
    applicantId,
    applicantName,
    applicantAvatar,
    message,
    status,
    createdAt,
    handledAt,
  ];
}

class GroupJoinRequestList extends Equatable {
  GroupJoinRequestList({
    required this.pendingCount,
    required List<GroupJoinRequest> requests,
  }) : requests = List<GroupJoinRequest>.unmodifiable(requests);

  factory GroupJoinRequestList.fromJson(Map<String, dynamic> json) {
    final rawRequests = json['requests'];
    if (rawRequests is! List) {
      throw const FormatException('Group join requests is not a list.');
    }
    return GroupJoinRequestList(
      pendingCount: _requiredInt(json, 'pending_count'),
      requests: rawRequests
          .map((dynamic item) {
            if (item is! Map) {
              throw const FormatException('Group join request is invalid.');
            }
            return GroupJoinRequest.fromJson(Map<String, dynamic>.from(item));
          })
          .toList(growable: false),
    );
  }

  final int pendingCount;
  final List<GroupJoinRequest> requests;

  @override
  List<Object?> get props => [pendingCount, requests];
}

GroupJoinRequestStatus _statusFromString(String value) => switch (value) {
  'approved' => GroupJoinRequestStatus.approved,
  'rejected' => GroupJoinRequestStatus.rejected,
  _ => GroupJoinRequestStatus.pending,
};

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  final parsed = int.tryParse('$value');
  if (parsed != null) return parsed;
  throw FormatException('Group field "$key" is required.');
}

String _string(dynamic value) => value is String ? value : '';

String? _nullableString(dynamic value) {
  final result = _string(value).trim();
  return result.isEmpty ? null : result;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _string(json[key]);
  if (value.isEmpty) throw FormatException('Group field "$key" is required.');
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final parsed = _nullableDateTime(json[key]);
  if (parsed != null) return parsed;
  throw FormatException('Group field "$key" is invalid.');
}

DateTime? _nullableDateTime(dynamic value) =>
    value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;
