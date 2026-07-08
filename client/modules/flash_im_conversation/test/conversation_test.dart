import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Conversation.fromJson maps backend snake_case payload', () {
    final conversation = Conversation.fromJson({
      'id': 'uuid-1',
      'type': 0,
      'name': null,
      'peer_user_id': '3',
      'peer_nickname': '橘橙',
      'peer_avatar': 'identicon:3',
      'last_message_at': '2026-03-29T09:12:00Z',
      'last_message_preview': '你好',
      'unread_count': 2,
      'created_at': '2026-03-29T08:00:00Z',
    });

    expect(conversation.id, 'uuid-1');
    expect(conversation.type, 0);
    expect(conversation.peerUserId, '3');
    expect(conversation.peerNickname, '橘橙');
    expect(conversation.peerAvatar, 'identicon:3');
    expect(conversation.lastMessageAt, DateTime.parse('2026-03-29T09:12:00Z'));
    expect(conversation.lastMessagePreview, '你好');
    expect(conversation.unreadCount, 2);
    expect(conversation.createdAt, DateTime.parse('2026-03-29T08:00:00Z'));
  });

  test('display fields fallback for empty private conversation', () {
    final createdAt = DateTime(2026, 3, 29, 8);
    final conversation = Conversation(
      id: 'uuid-2',
      type: 0,
      peerUserId: '10002',
      unreadCount: 0,
      createdAt: createdAt,
    );

    expect(conversation.displayName, '用户 10002');
    expect(conversation.displayPreview, '暂无消息');
    expect(conversation.displayTime, createdAt);
    expect(conversation.avatarSeed, '10002');
  });

  test('created_at is required', () {
    expect(
      () => Conversation.fromJson({'id': 'uuid-1'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('placeholder creates local skeleton conversation', () {
    final time = DateTime(2026, 4, 2, 9);
    final conversation = Conversation.placeholder(
      id: 'c1',
      lastMessagePreview: '新消息',
      lastMessageAt: time,
      unreadCount: 3,
    );

    expect(conversation.id, 'c1');
    expect(conversation.displayPreview, '新消息');
    expect(conversation.displayTime, time);
    expect(conversation.unreadCount, 3);
  });
}
