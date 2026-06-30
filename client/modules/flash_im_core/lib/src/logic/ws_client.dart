import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/im_config.dart';
import '../data/proto/ws.pb.dart';

typedef TokenProvider = FutureOr<String?> Function();
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

enum WsConnectionState {
  disconnected,
  connecting,
  authenticating,
  authenticated,
}

class WsClient {
  WsClient({
    required ImConfig config,
    required TokenProvider tokenProvider,
    WebSocketChannelFactory? channelFactory,
  }) : _config = config,
       _tokenProvider = tokenProvider,
       _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final ImConfig _config;
  final TokenProvider _tokenProvider;
  final WebSocketChannelFactory _channelFactory;
  final _stateController = StreamController<WsConnectionState>.broadcast();
  final _frameController = StreamController<WsFrame>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  WsConnectionState _state = WsConnectionState.disconnected;
  int _missedPongCount = 0;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  bool _manualDisconnect = false;

  Stream<WsConnectionState> get stateStream => _stateController.stream;
  Stream<WsFrame> get frameStream => _frameController.stream;
  WsConnectionState get state => _state;

  Future<void> connect() async {
    if (_disposed ||
        _state == WsConnectionState.connecting ||
        _state == WsConnectionState.authenticating ||
        _state == WsConnectionState.authenticated) {
      return;
    }

    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _emitState(WsConnectionState.connecting);

    try {
      final channel = _channelFactory(Uri.parse(_config.wsUrl));
      _channel = channel;
      await channel.ready;

      _channelSubscription = channel.stream.listen(
        _handleMessage,
        onError: (_) => _handleDisconnected(allowReconnect: true),
        onDone: () => _handleDisconnected(allowReconnect: true),
        cancelOnError: true,
      );

      final token = await _tokenProvider();
      if (token == null || token.isEmpty) {
        _handleDisconnected(allowReconnect: false);
        return;
      }

      _emitState(WsConnectionState.authenticating);
      sendFrame(
        WsFrame(
          type: WsFrameType.AUTH,
          payload: AuthRequest(token: token).writeToBuffer(),
        ),
      );
    } catch (_) {
      _handleDisconnected(allowReconnect: true);
    }
  }

  void sendFrame(WsFrame frame) {
    _channel?.sink.add(Uint8List.fromList(frame.writeToBuffer()));
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _closeChannel();
    _stopHeartbeat();
    _emitState(WsConnectionState.disconnected);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await disconnect();
    await _stateController.close();
    await _frameController.close();
  }

  void _handleMessage(dynamic message) {
    if (message is List<int>) {
      _handleBinaryMessage(message);
    }
  }

  void _handleBinaryMessage(List<int> bytes) {
    final frame = WsFrame.fromBuffer(bytes);
    switch (frame.type) {
      case WsFrameType.AUTH_RESULT:
        _handleAuthResult(frame.payload);
      case WsFrameType.PONG:
        _missedPongCount = 0;
      case WsFrameType.PING:
      case WsFrameType.AUTH:
        _frameController.add(frame);
    }
  }

  void _handleAuthResult(List<int> payload) {
    final result = AuthResult.fromBuffer(payload);
    if (result.success) {
      _reconnectAttempt = 0;
      _missedPongCount = 0;
      _emitState(WsConnectionState.authenticated);
      _startHeartbeat();
    } else {
      _handleDisconnected(allowReconnect: true);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_config.heartbeatInterval, (_) {
      _missedPongCount += 1;
      sendFrame(WsFrame(type: WsFrameType.PING));
      if (_missedPongCount >= _config.heartbeatTimeout) {
        _handleDisconnected(allowReconnect: true);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _missedPongCount = 0;
  }

  void _handleDisconnected({required bool allowReconnect}) {
    _stopHeartbeat();
    unawaited(_closeChannel());
    _emitState(WsConnectionState.disconnected);

    if (allowReconnect && !_manualDisconnect && !_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_nextReconnectDelay(), connect);
  }

  Duration _nextReconnectDelay() {
    final multiplier = math.pow(2, _reconnectAttempt).toInt();
    _reconnectAttempt += 1;
    final delayMs = _config.reconnectBaseDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: math.min(delayMs, _config.reconnectMaxDelay.inMilliseconds),
    );
  }

  Future<void> _closeChannel() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }

  void _emitState(WsConnectionState state) {
    if (_state == state || _stateController.isClosed) {
      return;
    }
    _state = state;
    _stateController.add(state);
  }
}
