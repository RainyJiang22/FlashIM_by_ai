import 'package:flash_im_core/src/data/proto/message.pb.dart';
import 'package:flash_im_core/src/data/proto/ws.pb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated proto classes can be constructed', () {
    final authRequest = AuthRequest(token: 'token');
    final authResult = AuthResult(success: true, message: 'ok');
    final frame = WsFrame(
      type: WsFrameType.AUTH,
      payload: authRequest.writeToBuffer(),
    );

    expect(frame.type, WsFrameType.AUTH);
    expect(authRequest.token, 'token');
    expect(authResult.success, isTrue);
    expect(authResult.message, 'ok');
    expect(frame.payload, isNotEmpty);
  });

  test('message proto classes encode and decode', () {
    final request = SendMessageRequest(
      conversationId: 'c1',
      type: 0,
      content: 'hello',
    );
    final decodedRequest = SendMessageRequest.fromBuffer(
      request.writeToBuffer(),
    );
    expect(decodedRequest.conversationId, 'c1');
    expect(decodedRequest.content, 'hello');

    final message = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      senderId: 2,
      seq: 1,
      content: 'hello',
      senderName: '朱红',
      senderAvatar: 'identicon:2',
    );
    final decodedMessage = ChatMessage.fromBuffer(message.writeToBuffer());
    expect(decodedMessage.senderName, '朱红');
    expect(decodedMessage.senderAvatar, 'identicon:2');
  });
}
