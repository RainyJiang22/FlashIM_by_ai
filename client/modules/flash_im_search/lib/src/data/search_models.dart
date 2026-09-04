import 'package:equatable/equatable.dart';
import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';

class MessageSearchGroup extends Equatable {
  MessageSearchGroup({
    required this.conversation,
    required this.matchCount,
    required List<Message> messages,
  }) : messages = List<Message>.unmodifiable(messages);

  factory MessageSearchGroup.fromJson(Map<String, dynamic> json) {
    final conversation = json['conversation'];
    final messages = json['messages'];
    if (conversation is! Map || messages is! List) {
      throw const FormatException('Message search group payload is invalid.');
    }
    return MessageSearchGroup(
      conversation: Conversation.fromJson(
        Map<String, dynamic>.from(conversation),
      ),
      matchCount: (json['match_count'] as num?)?.toInt() ?? messages.length,
      messages: messages
          .map((dynamic item) {
            if (item is! Map) {
              throw const FormatException('Message search item is invalid.');
            }
            return Message.fromJson(Map<String, dynamic>.from(item));
          })
          .toList(growable: false),
    );
  }

  final Conversation conversation;
  final int matchCount;
  final List<Message> messages;

  @override
  List<Object?> get props => [conversation, matchCount, messages];
}
