import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';

class MineInfoCard extends StatelessWidget {
  const MineInfoCard({
    super.key,
    required this.user,
    required this.onPasswordTap,
    required this.onLogout,
  });

  final User user;
  final VoidCallback onPasswordTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MineSection(
          children: [
            _MineInfoRow(label: '手机号', value: _maskPhone(user.phone)),
            _MineInfoRow(label: '闪讯号', value: user.userId.toString()),
            _MineInfoRow(
              label: '密码管理',
              value: user.hasPassword ? '修改密码' : '首次设置',
              onTap: onPasswordTap,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MineSection(
          children: [
            _MineInfoRow(
              label: '退出登录',
              value: '',
              destructive: true,
              onTap: onLogout,
            ),
          ],
        ),
      ],
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 5) {
      return phone;
    }
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 2)}';
  }
}

class _MineSection extends StatelessWidget {
  const _MineSection({required this.children});

  final List<_MineInfoRow> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i += 1) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 64, color: Color(0xFFEDEDED)),
          ],
        ],
      ),
    );
  }
}

class _MineInfoRow extends StatelessWidget {
  const _MineInfoRow({
    required this.label,
    required this.value,
    this.onTap,
    this.destructive = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                height: 1.15,
                color: destructive
                    ? const Color(0xFFE64340)
                    : const Color(0xFF191919),
              ),
            ),
          ),
          if (value.isNotEmpty)
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.15,
                  color: Color(0xFF8A8A8A),
                ),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFC7C7C7),
              size: 28,
            ),
          ],
        ],
      ),
    );

    final row = SizedBox(height: 56, child: child);
    if (onTap == null) {
      return row;
    }

    return InkWell(onTap: onTap, child: row);
  }
}
