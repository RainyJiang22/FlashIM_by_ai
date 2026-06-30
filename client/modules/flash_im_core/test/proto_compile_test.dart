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
}
