import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../data/group_detail.dart';

class GroupAdminPage extends StatefulWidget {
  const GroupAdminPage({
    super.key,
    required this.members,
    required this.onSave,
  });

  final List<GroupMember> members;
  final Future<bool> Function(List<int> memberIds) onSave;

  @override
  State<GroupAdminPage> createState() => _GroupAdminPageState();
}

class _GroupAdminPageState extends State<GroupAdminPage> {
  late final Set<int> _selectedIds;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.members
        .where((member) => member.isAdmin && !member.isOwner)
        .map((member) => member.accountId)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.members
        .where((member) => !member.isOwner)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('群管理员'),
        actions: [
          TextButton(
            key: const Key('group-admin-save'),
            onPressed: _isSaving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      backgroundColor: FlashPalette.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '管理员可在群聊中 @所有人。',
                style: TextStyle(color: FlashPalette.secondaryInk),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final member = candidates[index];
                final selected = _selectedIds.contains(member.accountId);
                return CheckboxListTile(
                  key: Key('group-admin-${member.accountId}'),
                  value: selected,
                  onChanged: _isSaving
                      ? null
                      : (_) => _toggle(member.accountId, selected),
                  secondary: AvatarWidget(
                    avatar: member.avatar,
                    seed: member.accountId.toString(),
                    size: 42,
                  ),
                  title: Text(member.displayName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(int memberId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.remove(memberId);
      } else {
        _selectedIds.add(memberId);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final saved = await widget.onSave(_selectedIds.toList(growable: false));
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) Navigator.of(context).pop();
  }
}
