import 'package:flash_im_chat/src/data/message.dart';
import 'package:flash_im_chat/src/logic/chat_state.dart';
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

  for (final entry in <MessageType, Key>{
    MessageType.text: const Key('text_bubble'),
    MessageType.image: const Key('image_bubble'),
    MessageType.video: const Key('video_bubble'),
    MessageType.file: const Key('file_bubble'),
  }.entries) {
    testWidgets('${entry.key.name} dispatches to matching bubble', (
      tester,
    ) async {
      final extra = switch (entry.key) {
        MessageType.video => const {
          'thumbnail_url': 'http://127.0.0.1/thumb.jpg',
          'duration_ms': 1000,
          'width': 320,
          'height': 180,
          'file_size': 10,
        },
        MessageType.file => const {
          'file_name': 'a.pdf',
          'file_url': 'http://127.0.0.1/a.pdf',
          'file_type': 'pdf',
          'file_size': 10,
        },
        _ => null,
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: Message(
                id: 'm-${entry.key.name}',
                conversationId: 'c1',
                senderId: '2',
                senderName: '朱红',
                seq: 1,
                content: entry.key == MessageType.text
                    ? 'hello'
                    : 'http://127.0.0.1/media',
                type: entry.key,
                extra: extra,
                status: MessageStatus.sent,
                createdAt: DateTime(2026, 7, 15),
              ),
              isMine: false,
              downloadInfo: entry.key == MessageType.file
                  ? const FileDownloadInfo(
                      status: FileDownloadStatus.downloading,
                      progress: 0.5,
                    )
                  : null,
            ),
          ),
        ),
      );

      expect(find.byKey(entry.value), findsOneWidget);
      if (entry.key == MessageType.file) {
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      }
    });
  }

  testWidgets('group invitation card accepts once and shows joined state', (
    tester,
  ) async {
    String? acceptedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'invite-1',
              conversationId: 'private-1',
              senderId: '2',
              senderName: '小雨',
              seq: 1,
              content: '邀请你加入群聊',
              type: MessageType.groupInvitation,
              extra: const {
                'invitation_id': 'invitation-1',
                'group_id': 'group-1',
                'group_name': '周末读书会',
                'inviter_name': '小雨',
              },
              status: MessageStatus.sent,
              createdAt: DateTime(2026, 8, 17),
            ),
            isMine: false,
            onAcceptGroupInvitation: (invitationId) async {
              acceptedId = invitationId;
            },
          ),
        ),
      ),
    );

    expect(find.text('周末读书会'), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-invitation-accept')));
    await tester.pumpAndSettle();
    expect(acceptedId, 'invitation-1');
    expect(find.text('已加入'), findsOneWidget);
  });
}
