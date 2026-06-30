import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImConfig', () {
    test('builds ws url from http api base url', () {
      final config = ImConfig.fromApiBaseUrl('http://127.0.0.1:9600/api');

      expect(config.wsUrl, 'ws://127.0.0.1:9600/ws/im');
      expect(config.heartbeatInterval, const Duration(seconds: 30));
      expect(config.heartbeatTimeout, 3);
      expect(config.reconnectBaseDelay, const Duration(seconds: 1));
      expect(config.reconnectMaxDelay, const Duration(seconds: 30));
    });

    test('builds wss url from https api base url', () {
      final config = ImConfig.fromApiBaseUrl('https://api.example.com/v1');

      expect(config.wsUrl, 'wss://api.example.com/ws/im');
    });
  });
}
