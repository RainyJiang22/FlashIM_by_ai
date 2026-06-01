// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/flash_im_app.dart';

void main() {
  testWidgets('home page can open fireworks show', (WidgetTester tester) async {
    await tester.pumpWidget(const FlashImApp());

    expect(find.text('flash_im'), findsOneWidget);
    expect(find.text('烟花秀'), findsOneWidget);

    await tester.tap(find.text('烟花秀'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('轻触屏幕，尽情庆祝。'), findsOneWidget);
  });
}
