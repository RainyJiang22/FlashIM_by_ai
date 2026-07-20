import 'package:flash_im_chat/src/view/video_player_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVideoDuration', () {
    test('formats minute duration', () {
      expect(formatVideoDuration(const Duration(seconds: 65)), '01:05');
    });

    test('formats hour duration', () {
      expect(
        formatVideoDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
    });
  });

  group('offsetVideoPosition', () {
    const duration = Duration(seconds: 30);

    test('moves position by the requested offset', () {
      expect(
        offsetVideoPosition(
          position: const Duration(seconds: 15),
          duration: duration,
          offset: const Duration(seconds: 10),
        ),
        const Duration(seconds: 25),
      );
    });

    test('clamps rewind to zero', () {
      expect(
        offsetVideoPosition(
          position: const Duration(seconds: 5),
          duration: duration,
          offset: const Duration(seconds: -10),
        ),
        Duration.zero,
      );
    });

    test('clamps fast forward to duration', () {
      expect(
        offsetVideoPosition(
          position: const Duration(seconds: 25),
          duration: duration,
          offset: const Duration(seconds: 10),
        ),
        duration,
      );
    });
  });
}
