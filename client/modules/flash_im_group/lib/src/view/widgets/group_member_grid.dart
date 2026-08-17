import 'package:flutter/material.dart';

import '../../data/group_detail.dart';
import 'group_member_tile.dart';

class GroupMemberGrid extends StatelessWidget {
  const GroupMemberGrid({
    super.key,
    required this.members,
    required this.isOwner,
    required this.isDeleteMode,
    required this.onAdd,
    required this.onToggleDelete,
    required this.onDeleteMember,
  });

  final List<GroupMember> members;
  final bool isOwner;
  final bool isDeleteMode;
  final VoidCallback onAdd;
  final VoidCallback onToggleDelete;
  final ValueChanged<GroupMember> onDeleteMember;

  @override
  Widget build(BuildContext context) {
    final itemCount = members.length + 1 + (isOwner ? 1 : 0);
    return GridView.builder(
      key: const Key('group-member-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisExtent: 86,
        crossAxisSpacing: 8,
        mainAxisSpacing: 6,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < members.length) {
          final member = members[index];
          return GroupMemberTile(
            member: member,
            showDelete: isDeleteMode && !member.isOwner,
            onDelete: () => onDeleteMember(member),
          );
        }
        if (index == members.length) {
          return GroupMemberActionTile(
            label: '添加',
            icon: Icons.add_rounded,
            onTap: onAdd,
          );
        }
        return GroupMemberActionTile(
          label: isDeleteMode ? '完成' : '删除',
          icon: isDeleteMode ? Icons.check_rounded : Icons.remove_rounded,
          isDanger: !isDeleteMode,
          onTap: onToggleDelete,
        );
      },
    );
  }
}
