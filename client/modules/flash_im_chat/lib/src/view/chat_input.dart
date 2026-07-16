import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const _cameraAvailabilityChannel = MethodChannel('flash_im/camera');

class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onSend,
    required this.onSendImage,
    required this.onSendVideo,
    required this.onSendFile,
    this.imagePicker,
    this.cameraAvailabilityChecker,
  });

  final ValueChanged<String> onSend;
  final ValueChanged<String> onSendImage;
  final ValueChanged<String> onSendVideo;
  final ValueChanged<String> onSendFile;
  final ImagePicker? imagePicker;
  final Future<bool> Function()? cameraAvailabilityChecker;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final ImagePicker _imagePicker;
  bool _panelVisible = false;

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? ImagePicker();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE7E7E7))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '更多',
                    onPressed: _togglePanel,
                    icon: Icon(
                      _panelVisible ? Icons.close : Icons.add_circle_outline,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: '输入消息',
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF6F7F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onTap: () {
                        if (_panelVisible) {
                          setState(() => _panelVisible = false);
                        }
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _controller.text.trim().isEmpty ? null : _send,
                    child: const Text('发送'),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: _panelVisible ? 112 : 0,
              child: ClipRect(
                child: OverflowBox(
                  minHeight: 112,
                  maxHeight: 112,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionItem(
                        icon: Icons.photo_outlined,
                        label: '照片',
                        onTap: _pickPhoto,
                      ),
                      _ActionItem(
                        icon: Icons.photo_camera_outlined,
                        label: '拍照',
                        onTap: _takePhoto,
                      ),
                      _ActionItem(
                        icon: Icons.videocam_outlined,
                        label: '视频',
                        onTap: _pickVideo,
                      ),
                      _ActionItem(
                        icon: Icons.insert_drive_file_outlined,
                        label: '文件',
                        onTap: _pickFile,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePanel() {
    _focusNode.unfocus();
    setState(() => _panelVisible = !_panelVisible);
  }

  Future<void> _pickPhoto() => _pickImage(ImageSource.gallery);

  Future<void> _takePhoto() async {
    if (await _isCameraUnavailable()) {
      _showToast('当前设备没有可用相机');
      _closePanel();
      return;
    }

    XFile? file;
    try {
      file = await _imagePicker.pickImage(source: ImageSource.camera);
    } on PlatformException catch (error) {
      final message = switch (error.code) {
        'camera_access_denied' || 'camera_access_restricted' => '请开启相机权限后重试',
        'no_available_camera' => '当前设备没有可用相机',
        _ => '相机暂时无法使用',
      };
      _showToast(message);
      _closePanel();
      return;
    } catch (_) {
      _showToast('相机暂时无法使用');
      _closePanel();
      return;
    }

    if (file != null) {
      widget.onSendImage(file.path);
    }
    _closePanel();
  }

  Future<bool> _isCameraUnavailable() async {
    final checker = widget.cameraAvailabilityChecker;
    if (checker != null) return !await checker();
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await _cameraAvailabilityChannel.invokeMethod<bool>(
            'isCameraAvailable',
          ) ==
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _imagePicker.pickImage(source: source);
    if (file != null) {
      widget.onSendImage(file.path);
    }
    _closePanel();
  }

  Future<void> _pickVideo() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      widget.onSendVideo(file.path);
    }
    _closePanel();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path != null) {
      widget.onSendFile(path);
    }
    _closePanel();
  }

  void _closePanel() {
    if (mounted) setState(() => _panelVisible = false);
  }

  void _showToast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {});
    widget.onSend(text);
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(icon),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
