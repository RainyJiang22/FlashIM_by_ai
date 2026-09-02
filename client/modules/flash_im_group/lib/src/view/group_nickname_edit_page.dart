import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class GroupNicknameEditPage extends StatefulWidget {
  const GroupNicknameEditPage({
    super.key,
    required this.initialNickname,
    required this.onSave,
  });

  final String initialNickname;
  final Future<bool> Function(String value) onSave;

  @override
  State<GroupNicknameEditPage> createState() => _GroupNicknameEditPageState();
}

class _GroupNicknameEditPageState extends State<GroupNicknameEditPage> {
  late final TextEditingController _controller;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我在本群的昵称'),
        actions: [
          TextButton(
            key: const Key('group-nickname-save'),
            onPressed: _isSaving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      backgroundColor: FlashPalette.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          key: const Key('group-nickname-input'),
          controller: _controller,
          autofocus: true,
          maxLength: 50,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            hintText: '请输入你在本群的昵称',
            filled: true,
            fillColor: FlashPalette.surface,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty || value.runes.length > 50 || _isSaving) return;
    setState(() => _isSaving = true);
    final saved = await widget.onSave(value);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) Navigator.of(context).pop();
  }
}
