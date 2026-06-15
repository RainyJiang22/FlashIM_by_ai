import 'package:flutter/material.dart';

import '../../domain/login_method.dart';

class AuthLoginModeSwitch extends StatelessWidget {
  const AuthLoginModeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LoginMethod value;
  final ValueChanged<LoginMethod> onChanged;

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
              height: 64,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOutCubic,
                    left: value == LoginMethod.smsCode ? 0 : indicatorWidth,
                    top: 0,
                    width: indicatorWidth,
                    height: 64,
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
                        child: _LoginModeButton(
                          isSelected: value == LoginMethod.smsCode,
                          label: '验证码登录',
                          onPressed: () => onChanged(LoginMethod.smsCode),
                        ),
                      ),
                      Expanded(
                        child: _LoginModeButton(
                          isSelected: value == LoginMethod.password,
                          label: '密码登录',
                          onPressed: () => onChanged(LoginMethod.password),
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

class _LoginModeButton extends StatelessWidget {
  const _LoginModeButton({
    required this.isSelected,
    required this.label,
    required this.onPressed,
  });

  final bool isSelected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        splashColor: const Color(0x126B8FF8),
        highlightColor: Colors.transparent,
        onTap: onPressed,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF17171F)
                  : const Color(0xFF8A8A95),
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
