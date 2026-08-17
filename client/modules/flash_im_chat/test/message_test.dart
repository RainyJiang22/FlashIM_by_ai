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

  test('Message.fromJson parses image type and JSON extra', () {
    final message = Message.fromJson({
      'id': 'image-1',
      'conversation_id': 'c1',
      'sender_id': 2,
      'msg_type': 1,
      'content': '/uploads/original/a.jpg',
      'extra': '{"width":640,"height":480,"thumbnail_url":"/thumb.jpg"}',
    });

    expect(message.type, MessageType.image);
    expect(message.isImage, isTrue);
    expect(message.extra?['width'], 640);
  });

  test('videoExtra and fileExtra expose formatted metadata', () {
    final video = Message.fromJson({
      'id': 'video-1',
      'conversation_id': 'c1',
      'sender_id': 1,
      'msg_type': 2,
      'content': '/tmp/thumb.jpg',
      'extra': {
        'thumbnail_url': '/thumb.jpg',
        'duration_ms': 83000,
        'width': 1280,
        'height': 720,
        'file_size': 2048,
      },
    });
    final file = Message.fromJson({
      'id': 'file-1',
      'conversation_id': 'c1',
      'sender_id': 1,
      'msg_type': 3,
      'content': '/uploads/file/a.pdf',
      'extra': {
        'file_name': 'a.pdf',
        'file_url': '/uploads/file/a.pdf',
        'file_type': 'pdf',
        'file_size': 1572864,
      },
    });

    expect(video.videoExtra?.formattedDuration, '1:23');
    expect(file.fileExtra?.formattedSize, '1.5 MB');
    expect(Message.mapToProtoType(MessageType.file), 3);
  });

  test('Message.local keeps selected media type', () {
    final local = Message.local(
      conversationId: 'c1',
      senderId: '1',
      senderName: '我',
      content: '/tmp/photo.jpg',
      type: MessageType.image,
    );

    expect(local.type, MessageType.image);
    expect(local.status, MessageStatus.sending);
  });

  test('group invitation parses card metadata and protocol type', () {
    final message = Message.fromJson({
      'id': 'invite-1',
      'conversation_id': 'private-1',
      'sender_id': 2,
      'msg_type': 4,
      'content': '邀请你加入群聊',
      'extra': {
        'invitation_id': 'invitation-1',
        'group_id': 'group-1',
        'group_name': '周末读书会',
        'inviter_name': '小雨',
      },
    });

    expect(message.type, MessageType.groupInvitation);
    expect(message.groupInvitationExtra?.groupName, '周末读书会');
    expect(Message.mapToProtoType(MessageType.groupInvitation), 4);
  });
}
