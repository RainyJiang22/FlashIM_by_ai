class ConversationDto {
  const ConversationDto({
    required this.title,
    required this.lastMessage,
    required this.time,
  });

  final String title;
  final String lastMessage;
  final String time;

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    return ConversationDto(
      title: json['title'] as String? ?? '',
      lastMessage: json['lastMsg'] as String? ?? '',
      time: json['time'] as String? ?? '',
    );
  }
}
