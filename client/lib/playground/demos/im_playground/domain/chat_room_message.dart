enum ChatRoomMessageKind { text, image, transfer, system }

class ChatRoomMessage {
  const ChatRoomMessage({
    required this.id,
    required this.kind,
    required this.isCurrentUser,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.createdAt,
    this.text,
    this.imageUrl,
    this.amountLabel,
    this.transferStatus,
    this.footerLabel,
  });

  final String id;
  final ChatRoomMessageKind kind;
  final bool isCurrentUser;
  final String senderName;
  final String senderAvatarUrl;
  final DateTime createdAt;
  final String? text;
  final String? imageUrl;
  final String? amountLabel;
  final String? transferStatus;
  final String? footerLabel;
}
