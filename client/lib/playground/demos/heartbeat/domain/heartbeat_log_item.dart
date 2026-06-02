import 'heartbeat_event.dart';

class HeartbeatLogItem {
  const HeartbeatLogItem({
    required this.direction,
    required this.message,
    required this.createdAt,
  });

  final HeartbeatMessageDirection direction;
  final String message;
  final DateTime createdAt;
}
