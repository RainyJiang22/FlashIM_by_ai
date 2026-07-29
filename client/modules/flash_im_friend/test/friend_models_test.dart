import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FriendUser parses relation and fallback display name', () {
    final user = FriendUser.fromJson(const <String, dynamic>{
      'account_id': 1001,
      'nickname': '',
      'avatar': 'identicon:1001',
      'signature': '保持联系',
      'flash_id': 'flash_1001',
      'relation_status': 'friend',
    });

    expect(user.accountId, 1001);
    expect(user.displayName, '用户 1001');
    expect(user.isFriend, isTrue);
  });

  test('FriendRequest parses nested user and time', () {
    final request = FriendRequest.fromJson(const <String, dynamic>{
      'id': 'r1',
      'from_user': <String, dynamic>{
        'account_id': 1002,
        'nickname': '小雨',
        'avatar': '',
        'signature': '',
      },
      'message': '我是小雨',
      'status': 'pending',
      'created_at': '2026-07-29T06:00:00Z',
    });

    expect(request.fromUser.displayName, '小雨');
    expect(request.message, '我是小雨');
    expect(request.createdAt.isUtc, isTrue);
    expect(request.isReceived, isTrue);
  });

  test('FriendRequest parses sent history with the target user', () {
    final request = FriendRequest.fromSentJson(const <String, dynamic>{
      'id': 'r2',
      'to_user': <String, dynamic>{
        'account_id': 1003,
        'nickname': '阿青',
        'avatar': '',
        'signature': '',
      },
      'message': '我是小雨',
      'status': 'accepted',
      'created_at': '2026-07-29T07:00:00Z',
    });

    expect(request.otherUser.displayName, '阿青');
    expect(request.direction, FriendRequestDirection.sent);
    expect(request.isPending, isFalse);
  });
}
