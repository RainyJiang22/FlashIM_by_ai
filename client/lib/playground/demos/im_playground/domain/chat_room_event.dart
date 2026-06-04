import 'chat_room_connection_status.dart';
import 'chat_room_message.dart';

enum ChatRoomEventType { status, message, error, pong }

class ChatRoomEvent {
  const ChatRoomEvent._({
    required this.type,
    this.status,
    this.message,
    this.errorMessage,
  });

  const ChatRoomEvent.status(ChatRoomConnectionStatus status)
    : this._(type: ChatRoomEventType.status, status: status);

  const ChatRoomEvent.message(ChatRoomMessage message)
    : this._(type: ChatRoomEventType.message, message: message);

  const ChatRoomEvent.error(String message)
    : this._(type: ChatRoomEventType.error, errorMessage: message);

  const ChatRoomEvent.pong()
    : this._(type: ChatRoomEventType.pong);

  final ChatRoomEventType type;
  final ChatRoomConnectionStatus? status;
  final ChatRoomMessage? message;
  final String? errorMessage;
}
