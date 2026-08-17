import 'package:equatable/equatable.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';

class GroupMember extends Equatable {
  const GroupMember({
    required this.accountId,
    required this.nickname,
    required this.avatar,
    required this.isOwner,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    accountId: _requiredInt(json, 'account_id'),
    nickname: _string(json['nickname']),
    avatar: _string(json['avatar']),
    isOwner: json['is_owner'] == true,
    joinedAt: _requiredDateTime(json, 'joined_at'),
  );

  final int accountId;
  final String nickname;
  final String avatar;
  final bool isOwner;
  final DateTime joinedAt;

  String get displayName =>
      nickname.trim().isEmpty ? '用户 $accountId' : nickname;

  @override
  List<Object?> get props => [accountId, nickname, avatar, isOwner, joinedAt];
}

class GroupDetail extends Equatable {
  GroupDetail({
    required this.conversationId,
    required this.name,
    required this.ownerId,
    required this.joinApprovalRequired,
    required this.currentUserRole,
    required this.memberCount,
    required List<GroupMember> members,
  }) : members = List<GroupMember>.unmodifiable(members);

  factory GroupDetail.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    if (rawMembers is! List) {
      throw const FormatException('GroupDetail members is not a list.');
    }
    return GroupDetail(
      conversationId: _requiredString(json, 'conversation_id'),
      name: _requiredString(json, 'name'),
      ownerId: _requiredInt(json, 'owner_id'),
      joinApprovalRequired: json['join_approval_required'] == true,
      currentUserRole: _requiredString(json, 'current_user_role'),
      memberCount: _requiredInt(json, 'member_count'),
      members: rawMembers
          .map((dynamic item) {
            if (item is! Map) {
              throw const FormatException('GroupDetail member is invalid.');
            }
            return GroupMember.fromJson(Map<String, dynamic>.from(item));
          })
          .toList(growable: false),
    );
  }

  final String conversationId;
  final String name;
  final int ownerId;
  final bool joinApprovalRequired;
  final String currentUserRole;
  final int memberCount;
  final List<GroupMember> members;

  bool get isOwner => currentUserRole == 'owner';

  Conversation applyToConversation(Conversation conversation) =>
      conversation.copyWith(
        name: name,
        memberAvatars: members.map((member) => member.avatar).take(4).toList(),
      );

  @override
  List<Object?> get props => [
    conversationId,
    name,
    ownerId,
    joinApprovalRequired,
    currentUserRole,
    memberCount,
    members,
  ];
}

enum GroupDetailsOutcome { updated, dissolved }

class GroupDetailsResult extends Equatable {
  const GroupDetailsResult.updated(this.conversation)
    : outcome = GroupDetailsOutcome.updated;

  const GroupDetailsResult.dissolved()
    : outcome = GroupDetailsOutcome.dissolved,
      conversation = null;

  final GroupDetailsOutcome outcome;
  final Conversation? conversation;

  bool get isDissolved => outcome == GroupDetailsOutcome.dissolved;

  @override
  List<Object?> get props => [outcome, conversation];
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toInt();
  }
  final parsed = int.tryParse('$value');
  if (parsed != null) return parsed;
  throw FormatException('GroupDetail field "$key" is required.');
}

String _string(dynamic value) => value is String ? value : '';

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _string(json[key]);
  if (value.isEmpty) {
    throw FormatException('GroupDetail field "$key" is required.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toLocal();
  }
  throw FormatException('GroupDetail field "$key" is invalid.');
}
