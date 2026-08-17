import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../../data/message.dart';

class GroupInvitationBubble extends StatefulWidget {
  const GroupInvitationBubble({
    super.key,
    required this.message,
    required this.canAccept,
    this.onAccept,
  });

  final Message message;
  final bool canAccept;
  final Future<void> Function(String invitationId)? onAccept;

  @override
  State<GroupInvitationBubble> createState() => _GroupInvitationBubbleState();
}

class _GroupInvitationBubbleState extends State<GroupInvitationBubble> {
  var _isAccepting = false;
  var _isAccepted = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final extra = widget.message.groupInvitationExtra;
    final valid = extra != null;
    return Container(
      key: const Key('group-invitation-bubble'),
      width: 244,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: FlashPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlashPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10172E59),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: FlashPalette.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: FlashPalette.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '邀请你加入群聊',
                      style: TextStyle(
                        color: FlashPalette.secondaryInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      extra?.groupName ?? '群邀请已失效',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlashPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            valid ? '${extra.inviterName} 邀请你加入' : '邀请信息不完整，暂时无法加入',
            style: const TextStyle(
              color: FlashPalette.secondaryInk,
              fontSize: 12,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: FlashPalette.danger, fontSize: 12),
            ),
          ],
          if (widget.canAccept) ...[
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('group-invitation-accept'),
                onPressed: !valid || _isAccepting || _isAccepted
                    ? null
                    : () => _accept(extra),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _isAccepting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isAccepted ? '已加入' : '同意加入'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _accept(GroupInvitationExtra extra) async {
    final callback = widget.onAccept;
    if (callback == null) return;
    setState(() {
      _isAccepting = true;
      _error = null;
    });
    try {
      await callback(extra.invitationId);
      if (mounted) {
        setState(() {
          _isAccepting = false;
          _isAccepted = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAccepting = false;
          _error = '加入失败，请稍后重试';
        });
      }
    }
  }
}
