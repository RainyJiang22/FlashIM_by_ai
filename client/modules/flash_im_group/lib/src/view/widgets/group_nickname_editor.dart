import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../group_nickname_edit_page.dart';

class GroupNicknameEditor extends StatelessWidget {
  const GroupNicknameEditor({
    super.key,
    required this.nickname,
    required this.canEdit,
    required this.onSave,
  });

  final String nickname;
  final bool canEdit;
  final Future<bool> Function(String value) onSave;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const Key('group-nickname-row'),
      title: const Text('我在本群的昵称'),
      subtitle: Text(nickname, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        builder: (_) =>
            GroupNicknameEditPage(initialNickname: nickname, onSave: onSave),
      ),
    );
  }
}
