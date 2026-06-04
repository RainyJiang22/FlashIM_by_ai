import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/chat_room_connection_status.dart';
import 'models/chat_room_socket_frame.dart';

abstract interface class ChatRoomRequest {
  Stream<ChatRoomApiEvent> connect({
    required String baseUrl,
    required String token,
  });

  Future<void> sendHeartbeat();

  Future<void> sendChat(String text);

  Future<void> disconnect();
}

class ChatRoomApiEvent {
  const ChatRoomApiEvent._({
    required this.type,
    this.status,
    this.frame,
    this.errorMessage,
  });

  const ChatRoomApiEvent.status(ChatRoomConnectionStatus status)
    : this._(type: ChatRoomApiEventType.status, status: status);

  const ChatRoomApiEvent.frame(ChatRoomSocketFrame frame)
    : this._(type: ChatRoomApiEventType.frame, frame: frame);

  const ChatRoomApiEvent.error(String message)
    : this._(type: ChatRoomApiEventType.error, errorMessage: message);

  final ChatRoomApiEventType type;
  final ChatRoomConnectionStatus? status;
  final ChatRoomSocketFrame? frame;
  final String? errorMessage;
}

enum ChatRoomApiEventType { status, frame, error }

class WebSocketChatRoomApi implements ChatRoomRequest {
  WebSocketChatRoomApi();

  WebSocketChannel? _channel;
  StreamController<ChatRoomApiEvent>? _controller;
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<ChatRoomApiEvent> connect({
    required String baseUrl,
    required String token,
  }) {
    final controller = StreamController<ChatRoomApiEvent>.broadcast();
    final channel = WebSocketChannel.connect(
      _buildWebSocketUri(baseUrl: baseUrl, token: token),
    );

    _controller = controller;
    _channel = channel;

    controller.add(
      const ChatRoomApiEvent.status(ChatRoomConnectionStatus.connecting),
    );

    () async {
      try {
        await channel.ready;
        if (!controller.isClosed) {
          controller.add(
            const ChatRoomApiEvent.status(ChatRoomConnectionStatus.connected),
          );
        }
      } catch (error) {
        if (!controller.isClosed) {
          controller.add(ChatRoomApiEvent.error('聊天室连接失败：$error'));
          controller.add(
            const ChatRoomApiEvent.status(ChatRoomConnectionStatus.disconnected),
          );
          await controller.close();
        }
      }
    }();

    _subscription = channel.stream.listen(
      (dynamic payload) {
        if (controller.isClosed) {
          return;
        }

        try {
          final frame = _parseFrame(payload);
          controller.add(ChatRoomApiEvent.frame(frame));
        } catch (error) {
          controller.add(ChatRoomApiEvent.error('聊天室消息解析失败：$error'));
        }
      },
      onError: (Object error, StackTrace stackTrace) async {
        if (!controller.isClosed) {
          controller.add(ChatRoomApiEvent.error('聊天室连接异常：$error'));
          controller.add(
            const ChatRoomApiEvent.status(ChatRoomConnectionStatus.disconnected),
          );
          await controller.close();
        }
      },
      onDone: () async {
        if (!controller.isClosed) {
          controller.add(
            const ChatRoomApiEvent.status(ChatRoomConnectionStatus.disconnected),
          );
          await controller.close();
        }
      },
      cancelOnError: true,
    );

    return controller.stream;
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

  @override
  Future<void> sendChat(String text) async {
    await _sendJson(<String, dynamic>{'type': 'chat', 'text': text});
  }

  @override
  Future<void> sendHeartbeat() async {
    await _sendJson(<String, dynamic>{'type': 'ping'});
  }

  Future<void> _sendJson(Map<String, dynamic> json) async {
    final channel = _channel;
    if (channel == null) {
      throw StateError('聊天室 WebSocket 尚未连接');
    }

    channel.sink.add(jsonEncode(json));
  }

  Uri _buildWebSocketUri({required String baseUrl, required String token}) {
    final httpUri = Uri.parse(baseUrl);
    final wsScheme = switch (httpUri.scheme) {
      'https' => 'wss',
      _ => 'ws',
    };

    return httpUri.replace(
      scheme: wsScheme,
      path: '/chat_room/ws',
      queryParameters: <String, String>{'token': token},
    );
  }

  ChatRoomSocketFrame _parseFrame(dynamic payload) {
    if (payload is! String) {
      throw const FormatException('聊天室返回的不是文本消息');
    }

    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      throw const FormatException('聊天室消息不是 JSON 对象');
    }

    return ChatRoomSocketFrame.fromJson(Map<String, dynamic>.from(decoded));
  }
}
