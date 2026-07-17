import 'package:flash_im_chat/src/view/chat_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
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
