import 'package:flash_session/flash_session.dart';
import 'package:flash_shared/flash_shared.dart';
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
            _MineInfoRow(
              icon: Icons.phone_iphone_rounded,
              label: '手机号',
              value: _maskPhone(user.phone),
            ),
            _MineInfoRow(
              icon: Icons.alternate_email_rounded,
              label: '闪讯号',
              value: user.userId.toString(),
            ),
            _MineInfoRow(
              icon: Icons.lock_outline_rounded,
              label: '密码管理',
              value: user.hasPassword ? '修改密码' : '首次设置',
              onTap: onPasswordTap,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MineSection(
          children: [
            _MineInfoRow(
              icon: Icons.logout_rounded,
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
    return Container(
      decoration: BoxDecoration(
        color: FlashPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlashPalette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i += 1) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(
                    height: 1,
                    indent: 66,
                    endIndent: 16,
                    color: FlashPalette.border,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MineInfoRow extends StatelessWidget {
  const _MineInfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.destructive = false,
  });

  final IconData? icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          if (destructive && value.isEmpty)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.15,
                  color: FlashPalette.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else ...[
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FlashPalette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: FlashPalette.primary, size: 19),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.15,
                  color: FlashPalette.ink,
                  fontWeight: FontWeight.w600,
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
                    fontSize: 14,
                    height: 1.15,
                    color: FlashPalette.secondaryInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: FlashPalette.mutedInk,
                size: 14,
              ),
            ],
          ],
        ],
      ),
    );

    final row = SizedBox(height: 64, child: child);
    if (onTap == null) {
      return row;
    }

    return InkWell(onTap: onTap, child: row);
  }
}
