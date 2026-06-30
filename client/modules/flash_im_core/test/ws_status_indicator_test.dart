import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides when authenticated', (tester) async {
    final client = _FakeWsClient(WsConnectionState.authenticated);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WsStatusIndicator(client: client)),
      ),
    );

    expect(find.text('正在连接...'), findsNothing);
    expect(find.text('连接已断开，正在重连...'), findsNothing);
  });

  testWidgets('shows disconnected message and reconnects on tap', (
    tester,
  ) async {
    final client = _FakeWsClient(WsConnectionState.disconnected);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WsStatusIndicator(client: client)),
      ),
    );

    expect(find.text('连接已断开，正在重连...'), findsOneWidget);
    await tester.tap(find.text('连接已断开，正在重连...'));
    expect(client.connectCount, 1);
  });
}

class _FakeWsClient extends WsClient {
  _FakeWsClient(this._state)
    : super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
        tokenProvider: () => null,
      );

  WsConnectionState _state;
  int connectCount = 0;

  @override
  WsConnectionState get state => _state;

  @override
  Stream<WsConnectionState> get stateStream => const Stream.empty();

  @override
  Future<void> connect() async {
    connectCount += 1;
    _state = WsConnectionState.connecting;
  }
}
