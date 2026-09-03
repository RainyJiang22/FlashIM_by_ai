import 'package:flash_im_chat/src/data/message.dart';
import 'package:flash_im_chat/src/logic/chat_state.dart';
import 'package:flash_im_chat/src/view/message_bubble.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mine private message shows read circle before bubble', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'read-private',
              conversationId: 'c1',
              senderId: '1',
              senderName: '我',
              seq: 3,
              content: 'hello',
              status: MessageStatus.sent,
              createdAt: DateTime(2026, 9, 3),
              readCount: 1,
            ),
            isMine: true,
          ),
        ),
      ),
    );

    expect(find.text('已读'), findsNothing);
    final indicator = find.byKey(const Key('private-message-read-indicator'));
    expect(indicator, findsOneWidget);
    expect(
      find.descendant(of: indicator, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      tester.getCenter(indicator).dx,
      lessThan(tester.getCenter(find.byKey(const Key('text_bubble'))).dx),
    );
  });

  testWidgets('mine unread private message shows hollow circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'unread-private',
              conversationId: 'c1',
              senderId: '1',
              senderName: '我',
              seq: 3,
              content: 'hello',
              status: MessageStatus.sent,
              createdAt: DateTime(2026, 9, 3),
            ),
            isMine: true,
          ),
        ),
      ),
    );

    final indicator = find.byKey(const Key('private-message-unread-indicator'));
    expect(indicator, findsOneWidget);
    expect(
      find.descendant(of: indicator, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
  });

  testWidgets('mine group message shows clickable reader count', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'read-group',
              conversationId: 'g1',
              senderId: '1',
              senderName: '我',
              seq: 3,
              content: 'hello',
              status: MessageStatus.sent,
              createdAt: DateTime(2026, 9, 3),
              readCount: 2,
            ),
            isMine: true,
            isGroupChat: true,
            onReadStatusTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('2 人已读'), findsOneWidget);
    await tester.tap(find.byKey(const Key('message-read-status')));
    expect(tapped, isTrue);
  });

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

  testWidgets('group system message shows centered pill content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: MessageBubble(
              message: Message(
                id: 'system-1',
                conversationId: 'group-1',
                senderId: '1',
                senderName: '小雨',
                seq: 1,
                content: '小雨 创建了群聊',
                type: MessageType.groupCreated,
                status: MessageStatus.sent,
                createdAt: DateTime(2026, 8, 28),
              ),
              isMine: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('group-created-message')), findsOneWidget);
    expect(find.byType(AvatarWidget), findsNothing);
    final text = tester.widget<Text>(find.text('小雨 创建了群聊'));
    expect(text.textAlign, TextAlign.center);
    expect(text.style?.color, FlashPalette.mutedInk);
    expect(tester.getCenter(find.text('小雨 创建了群聊')).dx, closeTo(180, 0.1));
  });

  testWidgets('invitation system message keeps inviter and invitee wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'system-invited-1',
              conversationId: 'group-1',
              senderId: '1',
              senderName: '朱红',
              seq: 3,
              content: '朱红 邀请 枫叶红 进群',
              extra: const {'system_event': 'member_invited'},
              type: MessageType.groupCreated,
              status: MessageStatus.sent,
              createdAt: DateTime(2026, 9, 1),
            ),
            isMine: true,
          ),
        ),
      ),
    );

    expect(find.text('朱红 邀请 枫叶红 进群'), findsOneWidget);
    expect(find.byType(AvatarWidget), findsNothing);
  });

  testWidgets('legacy group protocol payload never renders as a link', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'legacy-system-1',
              conversationId: 'group-1',
              senderId: '1',
              senderName: '小雨',
              seq: 1,
              content: 'https://cdn.example.com/avatar.webp',
              type: MessageType.groupCreated,
              status: MessageStatus.sent,
              createdAt: DateTime(2026, 8, 28),
            ),
            isMine: true,
          ),
        ),
      ),
    );

    expect(find.text('小雨 创建了群聊'), findsOneWidget);
    expect(find.text('https://cdn.example.com/avatar.webp'), findsNothing);
  });

  testWidgets('malformed system content still falls back by event type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'legacy-announcement-1',
              conversationId: 'group-1',
              senderId: '1',
              senderName: '系统助手',
              seq: 1,
              content: 'https://127.0.0.1/系统助手 更新了群公告',
              extra: const {'system_event': 'announcement_updated'},
              type: MessageType.groupCreated,
              status: MessageStatus.sent,
              createdAt: DateTime(2026, 9, 1),
            ),
            isMine: true,
          ),
        ),
      ),
    );

    expect(find.text('系统助手 更新了群公告'), findsOneWidget);
    expect(find.text('群聊信息已更新'), findsNothing);
  });

  testWidgets('member join system message keeps persisted join wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'system-joined-1',
              conversationId: 'group-1',
              senderId: '2',
              senderName: '阿青',
              seq: 2,
              content: '阿青 加入了群聊',
              extra: const {'system_event': 'member_joined'},
              type: MessageType.groupCreated,
              status: MessageStatus.sent,
              createdAt: DateTime(2026, 8, 31),
            ),
            isMine: true,
          ),
        ),
      ),
    );

    expect(find.text('阿青 加入了群聊'), findsOneWidget);
    expect(find.text('阿青 创建了群聊'), findsNothing);
    expect(find.byType(AvatarWidget), findsNothing);
  });
}
