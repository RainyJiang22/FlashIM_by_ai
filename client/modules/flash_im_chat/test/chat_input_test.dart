import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_chat/src/view/chat_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('typing @ opens multi-select mention picker and sends metadata', (
    tester,
  ) async {
    ChatTextMessageDraft? sentDraft;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(
            onSend: (_) {},
            onSendDraft: (draft) => sentDraft = draft,
            mentionDataLoader: () async => const ChatMentionPickerData(
              canMentionAll: false,
              members: [
                ChatMentionCandidate(userId: '2', displayName: '阿青'),
                ChatMentionCandidate(userId: '3', displayName: '白露'),
              ],
            ),
            onSendImage: (_) {},
            onSendVideo: (_) {},
            onSendFile: (_) {},
          ),
        ),
      ),
    );

    final input = find.byKey(const Key('chat-input-field'));
    await tester.enterText(input, '@');
    await tester.pumpAndSettle();
    expect(find.text('选择提醒的人'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mention-picker-2')));
    await tester.tap(find.byKey(const Key('mention-picker-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mention-picker-confirm')));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(input);
    expect(textField.controller?.text, '@阿青 @白露 ');
    await tester.enterText(input, '@阿青 @白露 请查看');
    await tester.tap(find.text('发送'));

    expect(sentDraft?.text, '@阿青 @白露 请查看');
    expect(sentDraft?.mentions.map((member) => member.userId), ['2', '3']);
    expect(sentDraft?.mentionAll, isFalse);
  });

  testWidgets('owner typing @ can select everyone', (tester) async {
    ChatTextMessageDraft? sentDraft;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(
            onSend: (_) {},
            onSendDraft: (draft) => sentDraft = draft,
            mentionDataLoader: () async =>
                const ChatMentionPickerData(canMentionAll: true, members: []),
            onSendImage: (_) {},
            onSendVideo: (_) {},
            onSendFile: (_) {},
          ),
        ),
      ),
    );

    final input = find.byKey(const Key('chat-input-field'));
    await tester.enterText(input, '@');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mention-picker-all')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mention-picker-confirm')));
    await tester.pumpAndSettle();
    await tester.enterText(input, '@所有人 开会');
    await tester.tap(find.text('发送'));

    expect(sentDraft?.mentionAll, isTrue);
    expect(sentDraft?.extra, {
      'mention_all': true,
      'mention_user_ids': <String>[],
    });
  });

  testWidgets('shows a toast when iOS reports no available camera', (
    tester,
  ) async {
    final imagePicker = _UnavailableCameraImagePicker();

    await _pumpChatInput(
      tester,
      imagePicker,
      cameraAvailabilityChecker: () async => false,
    );
    await _tapCamera(tester);

    expect(tester.takeException(), isNull);
    expect(imagePicker.wasCalled, isFalse);
    expect(find.text('当前设备没有可用相机'), findsOneWidget);
  });

  testWidgets('catches the no-camera platform exception and shows a toast', (
    tester,
  ) async {
    final imagePicker = _UnavailableCameraImagePicker();

    await _pumpChatInput(tester, imagePicker);
    await _tapCamera(tester);

    expect(tester.takeException(), isNull);
    expect(imagePicker.wasCalled, isTrue);
    expect(find.text('当前设备没有可用相机'), findsOneWidget);
  });
}

Future<void> _pumpChatInput(
  WidgetTester tester,
  ImagePicker imagePicker, {
  Future<bool> Function()? cameraAvailabilityChecker,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatInput(
          imagePicker: imagePicker,
          cameraAvailabilityChecker: cameraAvailabilityChecker,
          onSend: (_) {},
          onSendImage: (_) {},
          onSendVideo: (_) {},
          onSendFile: (_) {},
        ),
      ),
    ),
  );
}

Future<void> _tapCamera(WidgetTester tester) async {
  await tester.tap(find.byTooltip('更多'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('拍照'));
  await tester.pump();
}

class _UnavailableCameraImagePicker extends ImagePicker {
  bool wasCalled = false;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    wasCalled = true;
    throw PlatformException(
      code: 'no_available_camera',
      message: 'No cameras available for taking pictures.',
    );
  }
}
