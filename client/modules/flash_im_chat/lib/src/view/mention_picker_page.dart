import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../data/mention.dart';

class MentionPickerPage extends StatefulWidget {
  const MentionPickerPage({super.key, required this.data});

  final ChatMentionPickerData data;

  @override
  State<MentionPickerPage> createState() => _MentionPickerPageState();
}

class _MentionPickerPageState extends State<MentionPickerPage> {
  final _selectedIds = <String>{};
  var _mentionAll = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择提醒的人'),
        actions: [
          TextButton(
            key: const Key('mention-picker-confirm'),
            onPressed: _mentionAll || _selectedIds.isNotEmpty ? _confirm : null,
            child: const Text('完成'),
          ),
        ],
      ),
      backgroundColor: FlashPalette.background,
      body: ListView(
        children: [
          if (widget.data.canMentionAll) ...[
            CheckboxListTile(
              key: const Key('mention-picker-all'),
              value: _mentionAll,
              onChanged: (_) => setState(() {
                _mentionAll = !_mentionAll;
                if (_mentionAll) _selectedIds.clear();
              }),
              secondary: const CircleAvatar(
                backgroundColor: FlashPalette.primarySoft,
                child: Icon(Icons.campaign_rounded),
              ),
              title: const Text('所有人'),
              subtitle: const Text('提醒群内全部成员'),
            ),
            const Divider(height: 1),
          ],
          for (final member in widget.data.members)
            CheckboxListTile(
              key: Key('mention-picker-${member.userId}'),
              value: _selectedIds.contains(member.userId),
              onChanged: (_) => setState(() {
                _mentionAll = false;
                if (!_selectedIds.add(member.userId)) {
                  _selectedIds.remove(member.userId);
                }
              }),
              secondary: AvatarWidget(
                avatar: member.avatar,
                seed: member.userId,
                size: 42,
              ),
              title: Text(member.displayName),
            ),
        ],
      ),
    );
  }

  void _confirm() {
    if (_mentionAll) {
      Navigator.of(context).pop(const ChatMentionSelection.all());
      return;
    }
    final selected = widget.data.members
        .where((member) => _selectedIds.contains(member.userId))
        .toList(growable: false);
    Navigator.of(context).pop(ChatMentionSelection.members(selected));
  }
}
