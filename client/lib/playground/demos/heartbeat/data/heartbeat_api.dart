import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/heartbeat_connection_status.dart';
import '../domain/heartbeat_event.dart';

abstract interface class HeartbeatRequest {
  Stream<HeartbeatEvent> connect(String url);
  Future<void> sendText(String message);
  Future<void> disconnect();
}

class WebSocketHeartbeatApi implements HeartbeatRequest {
  WebSocketHeartbeatApi();

  WebSocketChannel? _channel;
  StreamController<HeartbeatEvent>? _controller;
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<HeartbeatEvent> connect(String url) {
    final controller = StreamController<HeartbeatEvent>.broadcast();
    final channel = WebSocketChannel.connect(Uri.parse(url));

    _controller = controller;
    _channel = channel;

    controller.add(
      const HeartbeatEvent.status(HeartbeatConnectionStatus.connecting),
    );

    () async {
      try {
        await channel.ready;
        if (!controller.isClosed) {
          controller.add(
            const HeartbeatEvent.status(HeartbeatConnectionStatus.connected),
          );
          controller.add(const HeartbeatEvent.system('WebSocket 已连接'));
        }
      } catch (error) {
        if (!controller.isClosed) {
          controller.add(HeartbeatEvent.system('连接失败：$error'));
          controller.add(
            const HeartbeatEvent.status(HeartbeatConnectionStatus.disconnected),
          );
          await controller.close();
        }
      }
    }();

    _subscription = channel.stream.listen(
      (dynamic message) {
        if (!controller.isClosed) {
          controller.add(
            HeartbeatEvent.message(
              direction: HeartbeatMessageDirection.incoming,
              message: '$message',
            ),
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) async {
        if (!controller.isClosed) {
          controller.add(HeartbeatEvent.system('连接异常：$error'));
          controller.add(
            const HeartbeatEvent.status(HeartbeatConnectionStatus.disconnected),
          );
          await controller.close();
        }
      },
      onDone: () async {
        if (!controller.isClosed) {
          controller.add(const HeartbeatEvent.system('WebSocket 已断开'));
          controller.add(
            const HeartbeatEvent.status(HeartbeatConnectionStatus.disconnected),
          );
          await controller.close();
        }
      },
      cancelOnError: true,
    );

    return controller.stream;
  }

  @override
  Future<void> sendText(String message) async {
    final channel = _channel;
    if (channel == null) {
      throw StateError('WebSocket 尚未连接');
    }

    channel.sink.add(message);
    _controller?.add(
      HeartbeatEvent.message(
        direction: HeartbeatMessageDirection.outgoing,
        message: message,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}
