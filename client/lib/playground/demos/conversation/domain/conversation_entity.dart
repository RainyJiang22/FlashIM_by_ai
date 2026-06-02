class ConversationEntity {
  const ConversationEntity({
    required this.title,
    required this.lastMessage,
    required this.time,
    required this.avatarUrl,
  });

  final String title;
  final String lastMessage;
  final String time;
  final String avatarUrl;
}
