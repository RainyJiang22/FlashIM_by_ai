import 'package:flutter/material.dart';

import '../../domain/auth_login_type.dart';

class AuthLoginModeSwitch extends StatelessWidget {
  const AuthLoginModeSwitch({
    super.key,
    required this.loginType,
    required this.onChanged,
  });

  final AuthLoginType loginType;
  final ValueChanged<AuthLoginType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const horizontalPadding = 4.0;
          final indicatorWidth =
              (constraints.maxWidth - horizontalPadding * 2) / 2;

          return Padding(
            padding: const EdgeInsets.all(horizontalPadding),
            child: SizedBox(
              height: 48,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOutCubic,
                    left: loginType == AuthLoginType.smsCode
                        ? 0
                        : indicatorWidth,
                    top: 0,
                    width: indicatorWidth,
                    height: 48,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeTapTarget(
                          label: '验证码登录',
                          selected: loginType == AuthLoginType.smsCode,
                          onTap: () => onChanged(AuthLoginType.smsCode),
                        ),
                      ),
                      Expanded(
                        child: _ModeTapTarget(
                          label: '密码登录',
                          selected: loginType == AuthLoginType.password,
                          onTap: () => onChanged(AuthLoginType.password),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeTapTarget extends StatelessWidget {
  const _ModeTapTarget({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        splashColor: const Color(0x126B8FF8),
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: selected ? const Color(0xFF17171F) : const Color(0xFF8A8A95),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
