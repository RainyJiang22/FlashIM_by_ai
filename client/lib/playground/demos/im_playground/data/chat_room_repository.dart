import '../../auth/domain/auth_profile.dart';
import '../domain/chat_room_event.dart';
import '../domain/chat_room_message.dart';
import 'chat_room_api.dart';
import 'models/chat_room_socket_frame.dart';

abstract interface class ChatRoomRepository {
  Stream<ChatRoomEvent> connect({
    required String baseUrl,
    required String token,
    required int currentUserId,
  });

  List<ChatRoomMessage> buildSeedMessages({required AuthProfile currentUser});

  Future<void> sendHeartbeat();

  Future<void> sendChat(String text);

  Future<void> disconnect();
}

class LiveChatRoomRepository implements ChatRoomRepository {
  LiveChatRoomRepository({required ChatRoomRequest request})
    : _request = request;

  static const String _peerName = '汪萱';
  static const String _peerAvatarUrl =
      'https://picsum.photos/seed/chat-room-peer/120/120';

  final ChatRoomRequest _request;
  int? _currentUserId;

  @override
  List<ChatRoomMessage> buildSeedMessages({required AuthProfile currentUser}) {
    return <ChatRoomMessage>[
      ChatRoomMessage(
        id: 'seed-1',
        kind: ChatRoomMessageKind.text,
        isCurrentUser: true,
        senderName: currentUser.nickname,
        senderAvatarUrl: currentUser.avatarUrl,
        createdAt: DateTime(2026, 5, 29, 20, 31),
        text: '绝交了',
      ),
      ChatRoomMessage(
        id: 'seed-2',
        kind: ChatRoomMessageKind.image,
        isCurrentUser: false,
        senderName: _peerName,
        senderAvatarUrl: _peerAvatarUrl,
        createdAt: DateTime(2026, 5, 29, 20, 33),
        imageUrl: 'https://picsum.photos/seed/chat-room-proof/360/520',
      ),
      ChatRoomMessage(
        id: 'seed-3',
        kind: ChatRoomMessageKind.text,
        isCurrentUser: false,
        senderName: _peerName,
        senderAvatarUrl: _peerAvatarUrl,
        createdAt: DateTime(2026, 5, 29, 20, 36),
        text: '你看看人家',
      ),
      ChatRoomMessage(
        id: 'seed-4',
        kind: ChatRoomMessageKind.text,
        isCurrentUser: true,
        senderName: currentUser.nickname,
        senderAvatarUrl: currentUser.avatarUrl,
        createdAt: DateTime(2026, 5, 29, 20, 37),
        text: '哦',
      ),
      ChatRoomMessage(
        id: 'seed-5',
        kind: ChatRoomMessageKind.image,
        isCurrentUser: false,
        senderName: _peerName,
        senderAvatarUrl: _peerAvatarUrl,
        createdAt: DateTime(2026, 5, 29, 20, 40),
        imageUrl: 'https://picsum.photos/seed/chat-room-dog/520/420',
      ),
      ChatRoomMessage(
        id: 'seed-6',
        kind: ChatRoomMessageKind.system,
        isCurrentUser: false,
        senderName: '',
        senderAvatarUrl: '',
        createdAt: DateTime(2026, 5, 29, 20, 43),
        text: '5月29日 晚上20:43',
      ),
      ChatRoomMessage(
        id: 'seed-7',
        kind: ChatRoomMessageKind.transfer,
        isCurrentUser: false,
        senderName: _peerName,
        senderAvatarUrl: _peerAvatarUrl,
        createdAt: DateTime(2026, 5, 29, 20, 44),
        amountLabel: '¥80.00',
        transferStatus: '已被接收',
        footerLabel: '微信转账',
      ),
      ChatRoomMessage(
        id: 'seed-8',
        kind: ChatRoomMessageKind.transfer,
        isCurrentUser: true,
        senderName: currentUser.nickname,
        senderAvatarUrl: currentUser.avatarUrl,
        createdAt: DateTime(2026, 5, 29, 20, 45),
        amountLabel: '¥80.00',
        transferStatus: '已收款',
        footerLabel: '微信转账',
      ),
    ];
  }

  @override
  Stream<ChatRoomEvent> connect({
    required String baseUrl,
    required String token,
    required int currentUserId,
  }) {
    _currentUserId = currentUserId;
    return _request.connect(baseUrl: baseUrl, token: token).asyncExpand((
      event,
    ) {
      final mappedEvent = _mapApiEvent(event);
      if (mappedEvent == null) {
        return const Stream<ChatRoomEvent>.empty();
      }

      return Stream<ChatRoomEvent>.value(mappedEvent);
    });
  }

  @override
  Future<void> disconnect() => _request.disconnect();

  @override
  Future<void> sendChat(String text) => _request.sendChat(text);

  @override
  Future<void> sendHeartbeat() => _request.sendHeartbeat();

  ChatRoomEvent? _mapApiEvent(ChatRoomApiEvent event) {
    switch (event.type) {
      case ChatRoomApiEventType.status:
        return ChatRoomEvent.status(event.status!);
      case ChatRoomApiEventType.error:
        return ChatRoomEvent.error(event.errorMessage ?? '聊天室异常');
      case ChatRoomApiEventType.frame:
        return _mapFrame(event.frame!);
    }
  }

  ChatRoomEvent? _mapFrame(ChatRoomSocketFrame frame) {
    final currentUserId = _currentUserId ?? 0;
    switch (frame.type) {
      case 'auth_ready':
        return null;
      case 'system':
        return null;
      case 'chat':
        return ChatRoomEvent.message(
          ChatRoomMessage(
            id: 'chat-${frame.messageId ?? frame.sentAt ?? 0}',
            kind: ChatRoomMessageKind.text,
            isCurrentUser: frame.userId == currentUserId,
            senderName: frame.nickname ?? '',
            senderAvatarUrl: frame.avatar ?? '',
            createdAt: _fromUnix(frame.sentAt),
            text: frame.text ?? '',
          ),
        );
      case 'pong':
        return const ChatRoomEvent.pong();
      case 'error':
        return ChatRoomEvent.error(frame.message ?? '聊天室返回错误');
      default:
        return null;
    }
  }

  DateTime _fromUnix(int? seconds) {
    final safeSeconds = seconds ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(safeSeconds * 1000);
  }
}
