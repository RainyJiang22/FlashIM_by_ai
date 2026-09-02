import 'package:equatable/equatable.dart';

class ChatMentionCandidate extends Equatable {
  const ChatMentionCandidate({
    required this.userId,
    required this.displayName,
    this.avatar,
  });

  final String userId;
  final String displayName;
  final String? avatar;

  @override
  List<Object?> get props => [userId, displayName, avatar];
}

class ChatMentionPickerData extends Equatable {
  const ChatMentionPickerData({
    required this.members,
    required this.canMentionAll,
  });

  final List<ChatMentionCandidate> members;
  final bool canMentionAll;

  @override
  List<Object?> get props => [members, canMentionAll];
}

class ChatMentionSelection extends Equatable {
  const ChatMentionSelection.members(this.members) : mentionAll = false;

  const ChatMentionSelection.all() : members = const [], mentionAll = true;

  final List<ChatMentionCandidate> members;
  final bool mentionAll;

  @override
  List<Object?> get props => [members, mentionAll];
}

class ChatTextMessageDraft extends Equatable {
  const ChatTextMessageDraft({
    required this.text,
    this.mentions = const [],
    this.mentionAll = false,
  });

  final String text;
  final List<ChatMentionCandidate> mentions;
  final bool mentionAll;

  Map<String, dynamic>? get extra {
    if (!mentionAll && mentions.isEmpty) return null;
    return {
      'mention_all': mentionAll,
      'mention_user_ids': mentions.map((member) => member.userId).toList(),
    };
  }

  @override
  List<Object?> get props => [text, mentions, mentionAll];
}

class ChatMentionMetadata extends Equatable {
  const ChatMentionMetadata({required this.mentionAll, required this.userIds});

  factory ChatMentionMetadata.fromExtra(Map<String, dynamic>? extra) {
    final rawMentions = extra?['mentions'];
    final userIds = <String>{};
    if (rawMentions is List) {
      for (final item in rawMentions) {
        if (item is Map && item['user_id'] != null) {
          userIds.add('${item['user_id']}');
        }
      }
    }
    return ChatMentionMetadata(
      mentionAll: extra?['mention_all'] == true,
      userIds: userIds,
    );
  }

  final bool mentionAll;
  final Set<String> userIds;

  bool mentionsUser(String userId) => mentionAll || userIds.contains(userId);

  @override
  List<Object?> get props => [mentionAll, userIds];
}
