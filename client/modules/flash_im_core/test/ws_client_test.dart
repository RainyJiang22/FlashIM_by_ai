import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
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

  test('dispatches typed message frames to streams', () async {
    final channel = _FakeWebSocketChannel();
    final client = WsClient(
      config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
      tokenProvider: () => 'jwt-token',
      channelFactory: (_) => channel,
    );
    final acks = <MessageAck>[];
    final updates = <ConversationUpdate>[];
    final messages = <ChatMessage>[];
    final ackSub = client.messageAckStream.listen(acks.add);
    final updateSub = client.conversationUpdateStream.listen(updates.add);
    final messageSub = client.chatMessageStream.listen(messages.add);

    await client.connect();
    channel.addFrame(
      WsFrame(
        type: WsFrameType.MESSAGE_ACK,
        payload: MessageAck(messageId: 'm1', seq: 1).writeToBuffer(),
      ),
    );
    channel.addFrame(
      WsFrame(
        type: WsFrameType.CONVERSATION_UPDATE,
        payload: ConversationUpdate(
          conversationId: 'c1',
          totalUnread: 3,
        ).writeToBuffer(),
      ),
    );
    channel.addFrame(
      WsFrame(
        type: WsFrameType.CHAT_MESSAGE,
        payload: ChatMessage(
          id: 'm2',
          conversationId: 'c1',
          content: 'hello',
        ).writeToBuffer(),
      ),
    );
    await _flushMicrotasks();

    expect(acks.single.seq, 1);
    expect(updates.single.totalUnread, 3);
    expect(messages.single.content, 'hello');

    await ackSub.cancel();
    await updateSub.cancel();
    await messageSub.cancel();
    await client.dispose();
  });

  test('dispatches typed friend frames to streams', () async {
    final channel = _FakeWebSocketChannel();
    final client = WsClient(
      config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
      tokenProvider: () => 'jwt-token',
      channelFactory: (_) => channel,
    );
    final requests = <FriendRequestEvent>[];
    final accepted = <FriendAcceptedEvent>[];
    final removed = <FriendRemovedEvent>[];
    final requestSub = client.friendRequestStream.listen(requests.add);
    final acceptedSub = client.friendAcceptedStream.listen(accepted.add);
    final removedSub = client.friendRemovedStream.listen(removed.add);

    await client.connect();
    channel.addFrame(
      WsFrame(
        type: WsFrameType.FRIEND_REQUEST,
        payload: FriendRequestEvent(
          requestId: 'r1',
          fromUser: FriendUser(nickname: '小雨'),
          message: '你好',
        ).writeToBuffer(),
      ),
    );
    channel.addFrame(
      WsFrame(
        type: WsFrameType.FRIEND_ACCEPTED,
        payload: FriendAcceptedEvent(
          requestId: 'r1',
          friend: FriendUser(nickname: '小雨'),
          conversationId: 'c1',
        ).writeToBuffer(),
      ),
    );
    channel.addFrame(
      WsFrame(
        type: WsFrameType.FRIEND_REMOVED,
        payload: FriendRemovedEvent(
          friend: FriendUser(nickname: '小雨'),
        ).writeToBuffer(),
      ),
    );
    await _flushMicrotasks();

    expect(requests.single.requestId, 'r1');
    expect(accepted.single.conversationId, 'c1');
    expect(removed.single.friend.nickname, '小雨');

    await requestSub.cancel();
    await acceptedSub.cancel();
    await removedSub.cancel();
    await client.dispose();
  });

  test('dispatches group join request frames to stream', () async {
    final channel = _FakeWebSocketChannel();
    final client = WsClient(
      config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
      tokenProvider: () => 'jwt-token',
      channelFactory: (_) => channel,
    );
    final events = <GroupJoinRequestNotification>[];
    final subscription = client.groupJoinRequestStream.listen(events.add);

    await client.connect();
    channel.addFrame(
      WsFrame(
        type: WsFrameType.GROUP_JOIN_REQUEST,
        payload: GroupJoinRequestNotification(
          requestId: 'r1',
          conversationId: 'g1',
          applicantId: Int64(10002),
          status: 0,
        ).writeToBuffer(),
      ),
    );
    await _flushMicrotasks();

    expect(events.single.requestId, 'r1');
    expect(events.single.conversationId, 'g1');
    expect(events.single.applicantId, Int64(10002));

    await subscription.cancel();
    await client.dispose();
  });

  test('dispatches group info update frames and closes the stream', () async {
    final channel = _FakeWebSocketChannel();
    final client = WsClient(
      config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
      tokenProvider: () => 'jwt-token',
      channelFactory: (_) => channel,
    );
    final events = <GroupInfoUpdateNotification>[];
    var streamDone = false;
    final subscription = client.groupInfoUpdateStream.listen(
      events.add,
      onDone: () => streamDone = true,
    );

    await client.connect();
    channel.addFrame(
      WsFrame(
        type: WsFrameType.GROUP_INFO_UPDATE,
        payload: GroupInfoUpdateNotification(
          conversationId: 'group-1',
          name: '治理群',
          ownerId: Int64(10002),
          memberCount: 3,
          membershipActive: true,
          currentUserRole: 'member',
          changeType: 'owner_transferred',
        ).writeToBuffer(),
      ),
    );
    await _flushMicrotasks();

    expect(events.single.conversationId, 'group-1');
    expect(events.single.ownerId, Int64(10002));
    expect(events.single.changeType, 'owner_transferred');

    await client.dispose();
    await _flushMicrotasks();
    expect(streamDone, isTrue);
    await subscription.cancel();
  });

  test('sendMessage wraps media fields in SendMessageRequest', () async {
    final channel = _FakeWebSocketChannel();
    final client = WsClient(
      config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
      tokenProvider: () => 'jwt-token',
      channelFactory: (_) => channel,
    );

    await client.connect();
    client.sendMessage(
      conversationId: 'c1',
      content: '/uploads/image/a.jpg',
      type: 1,
      extra: utf8.encode('{"width":320}'),
      clientId: 'local:1',
    );

    final frame = channel.sentFrames.last;
    expect(frame.type, WsFrameType.CHAT_MESSAGE);
    final request = SendMessageRequest.fromBuffer(frame.payload);
    expect(request.conversationId, 'c1');
    expect(request.type, 1);
    expect(request.content, '/uploads/image/a.jpg');
    expect(request.extra, '{"width":320}');
    expect(request.clientId, 'local:1');

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
