import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../group_name_edit_page.dart';

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
      onTap: canEdit ? () => _openEditor(context) : null,
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GroupNameEditPage(initialName: name, onSave: onSave),
      ),
    );
  }
}
