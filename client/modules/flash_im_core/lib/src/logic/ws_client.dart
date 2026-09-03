import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/im_config.dart';
import '../data/proto/friend.pb.dart';
import '../data/proto/group.pb.dart';
import '../data/proto/message.pb.dart';
import '../data/proto/presence.pb.dart';
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
  final _chatMessageController = StreamController<ChatMessage>.broadcast();
  final _messageAckController = StreamController<MessageAck>.broadcast();
  final _conversationUpdateController =
      StreamController<ConversationUpdate>.broadcast();
  final _friendRequestController =
      StreamController<FriendRequestEvent>.broadcast();
  final _friendAcceptedController =
      StreamController<FriendAcceptedEvent>.broadcast();
  final _friendRemovedController =
      StreamController<FriendRemovedEvent>.broadcast();
  final _groupJoinRequestController =
      StreamController<GroupJoinRequestNotification>.broadcast();
  final _groupInfoUpdateController =
      StreamController<GroupInfoUpdateNotification>.broadcast();
  final _userPresenceController =
      StreamController<UserPresenceEvent>.broadcast();
  final _onlineListController = StreamController<OnlineUserList>.broadcast();
  final _readReceiptController = StreamController<ReadReceipt>.broadcast();
  final ValueNotifier<Set<int>> _onlineUserIds = ValueNotifier(const <int>{});

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
  Stream<ChatMessage> get chatMessageStream => _chatMessageController.stream;
  Stream<MessageAck> get messageAckStream => _messageAckController.stream;
  Stream<ConversationUpdate> get conversationUpdateStream =>
      _conversationUpdateController.stream;
  Stream<FriendRequestEvent> get friendRequestStream =>
      _friendRequestController.stream;
  Stream<FriendAcceptedEvent> get friendAcceptedStream =>
      _friendAcceptedController.stream;
  Stream<FriendRemovedEvent> get friendRemovedStream =>
      _friendRemovedController.stream;
  Stream<GroupJoinRequestNotification> get groupJoinRequestStream =>
      _groupJoinRequestController.stream;
  Stream<GroupInfoUpdateNotification> get groupInfoUpdateStream =>
      _groupInfoUpdateController.stream;
  Stream<UserPresenceEvent> get userPresenceStream =>
      _userPresenceController.stream;
  Stream<OnlineUserList> get onlineListStream => _onlineListController.stream;
  Stream<ReadReceipt> get readReceiptStream => _readReceiptController.stream;
  ValueListenable<Set<int>> get onlineUserIds => _onlineUserIds;
  WsConnectionState get state => _state;

  bool isUserOnline(int userId) => _onlineUserIds.value.contains(userId);

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

  void sendChatMessage(SendMessageRequest request) {
    sendFrame(
      WsFrame(type: WsFrameType.CHAT_MESSAGE, payload: request.writeToBuffer()),
    );
  }

  void sendMessage({
    required String conversationId,
    required String content,
    required int type,
    List<int>? extra,
    String? clientId,
  }) {
    sendChatMessage(
      SendMessageRequest(
        conversationId: conversationId,
        type: type,
        content: content,
        extra: extra == null ? '' : utf8.decode(extra),
        clientId: clientId ?? '',
      ),
    );
  }

  bool sendReadReceipt({required String conversationId, required int readSeq}) {
    if (_state != WsConnectionState.authenticated || readSeq < 1) {
      return false;
    }
    sendFrame(
      WsFrame(
        type: WsFrameType.READ_RECEIPT,
        payload: ReadReceipt(
          conversationId: conversationId,
          readSeq: readSeq,
        ).writeToBuffer(),
      ),
    );
    return true;
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _closeChannel();
    _stopHeartbeat();
    _replaceOnlineUsers(const <int>[]);
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
    await _chatMessageController.close();
    await _messageAckController.close();
    await _conversationUpdateController.close();
    await _friendRequestController.close();
    await _friendAcceptedController.close();
    await _friendRemovedController.close();
    await _groupJoinRequestController.close();
    await _groupInfoUpdateController.close();
    await _userPresenceController.close();
    await _onlineListController.close();
    await _readReceiptController.close();
    _onlineUserIds.dispose();
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
      case WsFrameType.CHAT_MESSAGE:
        _chatMessageController.add(ChatMessage.fromBuffer(frame.payload));
        _frameController.add(frame);
      case WsFrameType.MESSAGE_ACK:
        _messageAckController.add(MessageAck.fromBuffer(frame.payload));
        _frameController.add(frame);
      case WsFrameType.CONVERSATION_UPDATE:
        _conversationUpdateController.add(
          ConversationUpdate.fromBuffer(frame.payload),
        );
        _frameController.add(frame);
      case WsFrameType.FRIEND_REQUEST:
        _friendRequestController.add(
          FriendRequestEvent.fromBuffer(frame.payload),
        );
        _frameController.add(frame);
      case WsFrameType.FRIEND_ACCEPTED:
        _friendAcceptedController.add(
          FriendAcceptedEvent.fromBuffer(frame.payload),
        );
        _frameController.add(frame);
      case WsFrameType.FRIEND_REMOVED:
        final event = FriendRemovedEvent.fromBuffer(frame.payload);
        _friendRemovedController.add(event);
        if (event.hasFriend()) {
          _setUserOnline(event.friend.accountId.toInt(), false);
        }
        _frameController.add(frame);
      case WsFrameType.GROUP_JOIN_REQUEST:
        _groupJoinRequestController.add(
          GroupJoinRequestNotification.fromBuffer(frame.payload),
        );
        _frameController.add(frame);
      case WsFrameType.GROUP_INFO_UPDATE:
        _groupInfoUpdateController.add(
          GroupInfoUpdateNotification.fromBuffer(frame.payload),
        );
        _frameController.add(frame);
      case WsFrameType.USER_ONLINE:
        final event = UserPresenceEvent.fromBuffer(frame.payload);
        _userPresenceController.add(event);
        _setUserOnline(event.userId.toInt(), true);
        _frameController.add(frame);
      case WsFrameType.USER_OFFLINE:
        final event = UserPresenceEvent.fromBuffer(frame.payload);
        _userPresenceController.add(event);
        _setUserOnline(event.userId.toInt(), false);
        _frameController.add(frame);
      case WsFrameType.ONLINE_LIST:
        final list = OnlineUserList.fromBuffer(frame.payload);
        _onlineListController.add(list);
        _replaceOnlineUsers(list.userIds.map((userId) => userId.toInt()));
        _frameController.add(frame);
      case WsFrameType.READ_RECEIPT:
        _readReceiptController.add(ReadReceipt.fromBuffer(frame.payload));
        _frameController.add(frame);
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
    _replaceOnlineUsers(const <int>[]);
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

  void _replaceOnlineUsers(Iterable<int> userIds) {
    final next = Set<int>.unmodifiable(userIds);
    if (setEquals(_onlineUserIds.value, next)) return;
    _onlineUserIds.value = next;
  }

  void _setUserOnline(int userId, bool isOnline) {
    final next = Set<int>.of(_onlineUserIds.value);
    final changed = isOnline ? next.add(userId) : next.remove(userId);
    if (changed) _onlineUserIds.value = Set<int>.unmodifiable(next);
  }
}
