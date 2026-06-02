import 'heartbeat_connection_status.dart';

enum HeartbeatMessageDirection { incoming, outgoing, system }

class HeartbeatEvent {
  const HeartbeatEvent._({
    required this.type,
    this.status,
    this.direction,
    this.message,
  });

  const HeartbeatEvent.status(HeartbeatConnectionStatus status)
    : this._(type: HeartbeatEventType.status, status: status);

  const HeartbeatEvent.message({
    required HeartbeatMessageDirection direction,
    required String message,
  }) : this._(
         type: HeartbeatEventType.message,
         direction: direction,
         message: message,
       );

  const HeartbeatEvent.system(String message)
    : this._(
        type: HeartbeatEventType.message,
        direction: HeartbeatMessageDirection.system,
        message: message,
      );

  final HeartbeatEventType type;
  final HeartbeatConnectionStatus? status;
  final HeartbeatMessageDirection? direction;
  final String? message;
}

enum HeartbeatEventType { status, message }
