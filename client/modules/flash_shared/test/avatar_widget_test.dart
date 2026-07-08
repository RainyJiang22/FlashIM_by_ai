import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AvatarWidget renders identicon fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AvatarWidget(avatar: null, seed: '10001')),
      ),
    );

    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  testWidgets('AvatarWidget supports identicon avatar value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarWidget(avatar: 'identicon:2', seed: 'fallback'),
        ),
      ),
    );

    expect(find.byType(IdenticonAvatar), findsOneWidget);
  });
}
