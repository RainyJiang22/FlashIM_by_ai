import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/playground/demos/auth/domain/auth_profile.dart';
import 'package:flash_im/playground/demos/im_playground/data/chat_room_api.dart';
import 'package:flash_im/playground/demos/im_playground/data/chat_room_repository.dart';
import 'package:flash_im/playground/demos/im_playground/data/models/chat_room_socket_frame.dart';
import 'package:flash_im/playground/demos/im_playground/domain/chat_room_connection_status.dart';
import 'package:flash_im/playground/demos/im_playground/domain/chat_room_event.dart';
import 'package:flash_im/playground/demos/im_playground/domain/chat_room_message.dart';

void main() {
  test(
    'chat room repository filters auth frames and keeps only chat messages',
    () async {
      final request = _FakeChatRoomRequest();
      final repository = LiveChatRoomRepository(request: request);

      final currentUser = const AuthProfile(
        userId: 1,
        nickname: '江小白',
        avatarUrl: 'https://picsum.photos/seed/self/120/120',
        phone: '18715079389',
      );

      final seedMessages = repository.buildSeedMessages(
        currentUser: currentUser,
      );
      expect(seedMessages, isNotEmpty);
      expect(seedMessages.first.kind, ChatRoomMessageKind.text);
      expect(seedMessages.last.kind, ChatRoomMessageKind.transfer);

      final events = <ChatRoomEvent>[];
      final done = Completer<void>();

      repository
          .connect(
            baseUrl: 'http://127.0.0.1:9600',
            token: 'jwt-token',
            currentUserId: 1,
          )
          .listen((event) {
            events.add(event);
            if (events.length >= 3 && !done.isCompleted) {
              done.complete();
            }
          });

      await done.future.timeout(const Duration(seconds: 3));

      expect(events.first.status, ChatRoomConnectionStatus.connected);
      expect(events[1].message?.isCurrentUser, isTrue);
      expect(events[2].message?.isCurrentUser, isFalse);
      expect(request.lastToken, 'jwt-token');
    },
  );
}

class _FakeChatRoomRequest implements ChatRoomRequest {
  String? lastToken;

  @override
  Stream<ChatRoomApiEvent> connect({
    required String baseUrl,
    required String token,
  }) async* {
    lastToken = token;
    yield const ChatRoomApiEvent.status(ChatRoomConnectionStatus.connected);
    yield ChatRoomApiEvent.frame(
      const ChatRoomSocketFrame(
        type: 'auth_ready',
        userId: 1,
        nickname: '江小白',
        avatar: 'https://picsum.photos/seed/self/120/120',
      ),
    );
    yield ChatRoomApiEvent.frame(
      const ChatRoomSocketFrame(
        type: 'chat',
        messageId: 1,
        userId: 1,
        nickname: '江小白',
        avatar: 'https://picsum.photos/seed/self/120/120',
        text: '我发的消息',
        sentAt: 1,
      ),
    );
    yield ChatRoomApiEvent.frame(
      const ChatRoomSocketFrame(
        type: 'chat',
        messageId: 2,
        userId: 9999001,
        nickname: '汪萱',
        avatar: 'https://picsum.photos/seed/chat-room-peer/120/120',
        text: '对方回复',
        sentAt: 2,
      ),
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendChat(String text) async {}

  @override
  Future<void> sendHeartbeat() async {}
}
