import 'package:flash_im_chat/src/data/message.dart';
import 'package:flash_im_chat/src/view/message_bubble.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mine message renders avatar on the right', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'm1',
              conversationId: 'c1',
              senderId: '1',
              senderName: '我',
              senderAvatar: 'identicon:old',
              seq: 1,
              content: 'hello',
              status: MessageStatus.sent,
              createdAt: DateTime(2026, 7, 8),
            ),
            isMine: true,
            currentUserAvatar: 'identicon:me',
          ),
        ),
      ),
    );

    expect(find.byType(AvatarWidget), findsOneWidget);
    final row = tester.widget<Row>(find.byType(Row).first);
    expect(row.children.last, isA<AvatarWidget>());
  });
}
