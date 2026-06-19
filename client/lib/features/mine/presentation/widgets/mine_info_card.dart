import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';

class MineInfoCard extends StatelessWidget {
  const MineInfoCard({
    super.key,
    required this.user,
    required this.onPasswordTap,
  });

  final User user;
  final VoidCallback onPasswordTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      shadowColor: const Color(0x101C4EFF),
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x101C4EFF),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _MineInfoRow(label: '手机号', value: _maskPhone(user.phone)),
            const Divider(height: 1),
            _MineInfoRow(label: '闪讯号', value: user.userId.toString()),
            const Divider(height: 1),
            _MineInfoRow(
              label: '密码管理',
              value: user.hasPassword ? '修改密码' : '首次设置',
              onTap: onPasswordTap,
            ),
          ],
        ),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 5) {
      return phone;
    }
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 2)}';
  }
}

class _MineInfoRow extends StatelessWidget {
  const _MineInfoRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6A7B92)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2A42),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A7BA)),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(onTap: onTap, child: child);
  }
}
