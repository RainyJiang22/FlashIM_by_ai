import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class GroupNameEditor extends StatelessWidget {
  const GroupNameEditor({
    super.key,
    required this.name,
    required this.canEdit,
    required this.onSave,
  });

  final String name;
  final bool canEdit;
  final Future<bool> Function(String value) onSave;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const Key('group-name-row'),
      title: const Text('群聊名称'),
      subtitle: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: canEdit
          ? const Icon(
              Icons.chevron_right_rounded,
              color: FlashPalette.mutedInk,
            )
          : null,
      onTap: canEdit ? () => _showEditor(context) : null,
    );
  }

  Future<void> _showEditor(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _GroupNameEditDialog(initialValue: name),
    );
    if (value != null) await onSave(value);
  }
}

class _GroupNameEditDialog extends StatefulWidget {
  const _GroupNameEditDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_GroupNameEditDialog> createState() => _GroupNameEditDialogState();
}

class _GroupNameEditDialogState extends State<_GroupNameEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改群聊名称'),
      content: TextField(
        key: const Key('group-name-input'),
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(hintText: '请输入群聊名称'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('group-name-save'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
