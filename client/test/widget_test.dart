// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/flash_im_app.dart';

void main() {
  testWidgets('main app opens the playground list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FlashImApp());

    expect(find.text('flash_im playground'), findsOneWidget);
    expect(find.text('conversation'), findsOneWidget);
    expect(find.text('心跳通信'), findsOneWidget);
    expect(find.text('烟花秀'), findsOneWidget);
  });
}
