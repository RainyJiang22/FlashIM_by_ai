import 'dart:async';
import 'dart:typed_data';

import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_im_core/src/data/proto/ws.pb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('connect sends auth frame and authenticates on auth result', () async {
    final channel = _FakeWebSocketChannel();
    Uri? requestedUri;
    final client = WsClient(
      config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
      tokenProvider: () => 'jwt-token',
      channelFactory: (uri) {
        requestedUri = uri;
        return channel;
      },
    );
    final states = <WsConnectionState>[];
    final subscription = client.stateStream.listen(states.add);

    await client.connect();
    await _flushMicrotasks();

    expect(requestedUri, Uri.parse('ws://127.0.0.1:9600/ws/im'));
    final authFrame = channel.sentFrames.single;
    expect(authFrame.type, WsFrameType.AUTH);
    expect(AuthRequest.fromBuffer(authFrame.payload).token, 'jwt-token');
    expect(states, [
      WsConnectionState.connecting,
      WsConnectionState.authenticating,
    ]);

    channel.addFrame(
      WsFrame(
        type: WsFrameType.AUTH_RESULT,
        payload: AuthResult(success: true).writeToBuffer(),
      ),
    );
    await _flushMicrotasks();

    expect(client.state, WsConnectionState.authenticated);
    expect(states.last, WsConnectionState.authenticated);

    await subscription.cancel();
    await client.dispose();
  });

  test('heartbeat sends ping after authentication', () async {
    final channel = _FakeWebSocketChannel();
    final client = WsClient(
      config: ImConfig(
        wsUrl: 'ws://127.0.0.1:9600/ws/im',
        heartbeatInterval: const Duration(milliseconds: 10),
        heartbeatTimeout: 5,
      ),
      tokenProvider: () => 'jwt-token',
      channelFactory: (_) => channel,
    );

    await client.connect();
    channel.addFrame(
      WsFrame(
        type: WsFrameType.AUTH_RESULT,
        payload: AuthResult(success: true).writeToBuffer(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(
      channel.sentFrames.where((frame) => frame.type == WsFrameType.PING),
      isNotEmpty,
    );

    await client.dispose();
  });

  test('missing token disconnects without sending auth frame', () async {
    final channel = _FakeWebSocketChannel();
    final client = WsClient(
      config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
      tokenProvider: () => null,
      channelFactory: (_) => channel,
    );

    await client.connect();

    expect(client.state, WsConnectionState.disconnected);
    expect(channel.sentFrames, isEmpty);

    await client.dispose();
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

class _FakeWebSocketChannel
    with StreamChannelMixin
    implements WebSocketChannel {
  _FakeWebSocketChannel()
    : _incoming = StreamController<dynamic>(),
      _sent = StreamController<dynamic>.broadcast(),
      sentFrames = <WsFrame>[] {
    sink = _FakeWebSocketSink(_sent, _incoming.close, sentFrames);
  }

  final StreamController<dynamic> _incoming;
  final StreamController<dynamic> _sent;
  final List<WsFrame> sentFrames;

  @override
  late final WebSocketSink sink;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future<void>.value();

  void addFrame(WsFrame frame) {
    _incoming.add(Uint8List.fromList(frame.writeToBuffer()));
  }
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._sent, this._closeIncoming, this._sentFrames);

  final StreamController<dynamic> _sent;
  final Future<void> Function() _closeIncoming;
  final List<WsFrame> _sentFrames;

  @override
  Future<void> get done => _sent.done;

  @override
  void add(dynamic data) {
    _sent.add(data);
    if (data is List<int>) {
      _sentFrames.add(WsFrame.fromBuffer(data));
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _sent.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<dynamic> stream) {
    return _sent.addStream(stream);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    await _closeIncoming();
    await _sent.close();
  }
}
