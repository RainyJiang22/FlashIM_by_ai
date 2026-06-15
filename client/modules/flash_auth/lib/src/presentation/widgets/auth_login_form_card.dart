import 'package:flutter/material.dart';

import '../../domain/login_method.dart';
import 'auth_login_header.dart';
import 'auth_login_mode_switch.dart';

class AuthLoginFormCard extends StatelessWidget {
  const AuthLoginFormCard({
    super.key,
    required this.method,
    required this.phoneController,
    required this.codeController,
    required this.passwordController,
    required this.inlineError,
    required this.isSendingCode,
    required this.cooldownSeconds,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onMethodChanged,
    required this.onSendCode,
    required this.onSubmit,
  });

  final LoginMethod method;
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final TextEditingController passwordController;
  final String? inlineError;
  final bool isSendingCode;
  final int cooldownSeconds;
  final bool isSubmitting;
  final bool canSubmit;
  final ValueChanged<LoginMethod> onMethodChanged;
  final VoidCallback onSendCode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141C4EFF),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: AuthLoginHeader()),
            const SizedBox(height: 28),
            AuthLoginModeSwitch(value: method, onChanged: onMethodChanged),
            const SizedBox(height: 20),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '手机号',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _AuthCredentialSection(
              method: method,
              codeController: codeController,
              passwordController: passwordController,
              isSendingCode: isSendingCode,
              cooldownSeconds: cooldownSeconds,
              onSendCode: onSendCode,
            ),
            if (inlineError != null) ...[
              const SizedBox(height: 12),
              Text(
                inlineError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFE35D6A),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmit ? onSubmit : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(isSubmitting ? '登录中...' : '登录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthCredentialSection extends StatelessWidget {
  const _AuthCredentialSection({
    required this.method,
    required this.codeController,
    required this.passwordController,
    required this.isSendingCode,
    required this.cooldownSeconds,
    required this.onSendCode,
  });

  final LoginMethod method;
  final TextEditingController codeController;
  final TextEditingController passwordController;
  final bool isSendingCode;
  final int cooldownSeconds;
  final VoidCallback onSendCode;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          reverseDuration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offset = Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
          child: method == LoginMethod.smsCode
              ? _AuthAnimatedCredential(
                  key: const ValueKey('sms-code-fields'),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 116,
                        child: OutlinedButton(
                          onPressed: isSendingCode || cooldownSeconds > 0
                              ? null
                              : onSendCode,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(64),
                          ),
                          child: Text(
                            isSendingCode
                                ? '发送中...'
                                : cooldownSeconds > 0
                                ? '${cooldownSeconds}s'
                                : '发送',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _AuthAnimatedCredential(
                  key: const ValueKey('password-fields'),
                  child: TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _AuthAnimatedCredential extends StatelessWidget {
  const _AuthAnimatedCredential({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
