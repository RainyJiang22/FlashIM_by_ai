import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../data/group_detail.dart';

class TransferGroupOwnerPage extends StatefulWidget {
  const TransferGroupOwnerPage({
    super.key,
    required this.members,
    required this.onTransfer,
  });

  final List<GroupMember> members;
  final Future<bool> Function(int memberId) onTransfer;

  @override
  State<TransferGroupOwnerPage> createState() => _TransferGroupOwnerPageState();
}

class _TransferGroupOwnerPageState extends State<TransferGroupOwnerPage> {
  var _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final candidates = widget.members
        .where((member) => !member.isOwner)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('转让群主')),
      backgroundColor: FlashPalette.background,
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: candidates.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final member = candidates[index];
          return ListTile(
            key: Key('transfer-owner-${member.accountId}'),
            enabled: !_isSaving,
            tileColor: FlashPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: AvatarWidget(
              avatar: member.avatar,
              seed: '${member.accountId}',
              size: 42,
              borderRadius: BorderRadius.circular(13),
            ),
            title: Text(member.displayName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _confirm(member),
          );
        },
      ),
    );
  }

  Future<void> _confirm(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('转让群主'),
        content: Text('确定将群主转让给“${member.displayName}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('transfer-owner-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认转让'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    final transferred = await widget.onTransfer(member.accountId);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (transferred) Navigator.of(context).pop();
  }
}
