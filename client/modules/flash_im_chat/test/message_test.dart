import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_core/flash_im_core.dart' as proto;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Message.fromJson maps backend payload', () {
    final message = Message.fromJson({
      'id': 'm1',
      'conversation_id': 'c1',
      'sender_id': '2',
      'sender_name': '朱红',
      'sender_avatar': 'identicon:2',
      'seq': 1,
      'content': 'hello',
      'created_at': '2026-04-02T09:00:00Z',
    });

    expect(message.id, 'm1');
    expect(message.senderName, '朱红');
    expect(message.status, MessageStatus.sent);
  });

  test('Message.fromChatMessage maps realtime payload', () {
    final message = Message.fromChatMessage(
      proto.ChatMessage(
        id: 'm1',
        conversationId: 'c1',
        senderId: 2,
        seq: 1,
        content: 'hello',
        senderName: '朱红',
      ),
    );

    expect(message.senderId, '2');
    expect(message.content, 'hello');
  });
}
