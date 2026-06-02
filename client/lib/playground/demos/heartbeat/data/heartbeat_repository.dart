import '../domain/heartbeat_event.dart';
import 'heartbeat_api.dart';

abstract interface class HeartbeatRepository {
  Stream<HeartbeatEvent> connect(String url);
  Future<void> sendHeartbeat();
  Future<void> sendText(String message);
  Future<void> disconnect();
}

class LiveHeartbeatRepository implements HeartbeatRepository {
  LiveHeartbeatRepository({required HeartbeatRequest request})
    : _request = request;

  final HeartbeatRequest _request;

  @override
  Stream<HeartbeatEvent> connect(String url) => _request.connect(url);

  @override
  Future<void> disconnect() => _request.disconnect();

  @override
  Future<void> sendHeartbeat() => _request.sendText('ping');

  @override
  Future<void> sendText(String message) => _request.sendText(message);
}
