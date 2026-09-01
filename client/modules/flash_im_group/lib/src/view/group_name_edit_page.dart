import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class GroupNameEditPage extends StatefulWidget {
  const GroupNameEditPage({
    super.key,
    required this.initialName,
    required this.onSave,
  });

  final String initialName;
  final Future<bool> Function(String value) onSave;

  @override
  State<GroupNameEditPage> createState() => _GroupNameEditPageState();
}

class _GroupNameEditPageState extends State<GroupNameEditPage> {
  late final TextEditingController _controller;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
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
        title: const Text('群聊名称'),
        actions: [
          TextButton(
            key: const Key('group-name-save'),
            onPressed: _isSaving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      backgroundColor: FlashPalette.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          key: const Key('group-name-input'),
          controller: _controller,
          autofocus: true,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            hintText: '请输入群聊名称',
            filled: true,
            fillColor: FlashPalette.surface,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty || value.runes.length > 100 || _isSaving) return;
    setState(() => _isSaving = true);
    final saved = await widget.onSave(value);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) Navigator.of(context).pop();
  }
}
