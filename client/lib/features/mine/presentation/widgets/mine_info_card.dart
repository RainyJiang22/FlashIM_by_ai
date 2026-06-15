import 'package:flutter/material.dart';

import '../../../auth/domain/auth_profile.dart';

class MineInfoCard extends StatelessWidget {
  const MineInfoCard({super.key, required this.profile});

  final AuthProfile profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
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
          _MineInfoRow(label: '账户 ID', value: profile.accountId.toString()),
          const Divider(height: 1),
          _MineInfoRow(label: '昵称', value: profile.nickname),
          const Divider(height: 1),
          _MineInfoRow(label: '手机号', value: profile.phone),
          const Divider(height: 1),
          _MineInfoRow(
            label: '密码状态',
            value: profile.hasPassword ? '已设置' : '未设置',
          ),
        ],
      ),
    );
  }
}

class _MineInfoRow extends StatelessWidget {
  const _MineInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
        ],
      ),
    );
  }
}
