import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/app_router.dart';
import '../cubit/app_session_cubit.dart';
import '../data/auth_repository.dart';
import '../domain/auth_status.dart';
import '../domain/login_method.dart';
import 'widgets/auth_login_mode_switch.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const int _cooldownTotalSeconds = 60;

  late final TextEditingController _phoneController;
  late final TextEditingController _codeController;
  late final TextEditingController _passwordController;

  Timer? _countdownTimer;
  LoginMethod _method = LoginMethod.smsCode;
  bool _isSendingCode = false;
  bool _isSubmitting = false;
  int _cooldownSeconds = 0;
  String? _inlineError;

  AuthRepository get _repository => context.read<AuthRepository>();

  bool get _canSubmit {
    switch (_method) {
      case LoginMethod.smsCode:
        return _phoneController.text.trim().isNotEmpty &&
            _codeController.text.trim().isNotEmpty &&
            !_isSubmitting;
      case LoginMethod.password:
        return _phoneController.text.trim().isNotEmpty &&
            _passwordController.text.trim().isNotEmpty &&
            !_isSubmitting;
    }
  }

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _codeController = TextEditingController();
    _passwordController = TextEditingController();
    _phoneController.addListener(_handleInputChanged);
    _codeController.addListener(_handleInputChanged);
    _passwordController.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _codeController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _passwordController
      ..removeListener(_handleInputChanged)
      ..dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _inlineError = '请先输入手机号';
      });
      return;
    }

    setState(() {
      _isSendingCode = true;
      _inlineError = null;
    });

    try {
      final code = await _repository.sendSmsCode(phone);
      if (!mounted) {
        return;
      }
      if (kDebugMode) {
        _codeController.text = code;
        _codeController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: code.length,
        );
      }
      _startCountdown();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = _readErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();

    if (_method == LoginMethod.smsCode && (phone.isEmpty || code.isEmpty)) {
      setState(() {
        _inlineError = '请输入手机号和验证码';
      });
      return;
    }

    if (_method == LoginMethod.password &&
        (phone.isEmpty || password.isEmpty)) {
      setState(() {
        _inlineError = '请输入手机号和密码';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      final session = switch (_method) {
        LoginMethod.smsCode => await _repository.loginWithSmsCode(
          phone: phone,
          code: code,
        ),
        LoginMethod.password => await _repository.loginWithPassword(
          identifier: phone,
          password: password,
        ),
      };
      if (!mounted) {
        return;
      }
      await context.read<AppSessionCubit>().completeLogin(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = _readErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _cooldownSeconds = _cooldownTotalSeconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
        });
        return;
      }

      setState(() {
        _cooldownSeconds -= 1;
      });
    });
  }

  String _readErrorMessage(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return _method == LoginMethod.password ? '手机号或密码错误' : '验证码错误或已过期';
      }
      final payload = error.response?.data;
      if (payload is Map && payload['message'] is String) {
        return payload['message'] as String;
      }
      return error.message ?? '登录失败，请稍后重试';
    }

    return '登录失败，请稍后重试';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<AppSessionCubit, AppSessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == AuthStatus.authenticated,
      listener: (context, state) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DecoratedBox(
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
                        Center(
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/branding/flash_im_logo.png',
                                width: 84,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Flash IM',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1C4EFF),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '轻量、干净、直接的体验',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF6A7B92),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        AuthLoginModeSwitch(
                          value: _method,
                          onChanged: (value) {
                            if (_method == value) {
                              return;
                            }
                            FocusScope.of(context).unfocus();
                            setState(() {
                              _method = value;
                              _inlineError = null;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: '手机号',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AnimatedCredentialSection(
                          child: _method == LoginMethod.smsCode
                              ? _CredentialSection(
                                  key: const ValueKey('sms-code-fields'),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _codeController,
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
                                          onPressed:
                                              _isSendingCode ||
                                                  _cooldownSeconds > 0
                                              ? null
                                              : _sendCode,
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(
                                              64,
                                            ),
                                          ),
                                          child: Text(
                                            _isSendingCode
                                                ? '发送中...'
                                                : _cooldownSeconds > 0
                                                ? '${_cooldownSeconds}s'
                                                : '发送',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _CredentialSection(
                                  key: const ValueKey('password-fields'),
                                  child: TextField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: '密码',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                        ),
                        if (_inlineError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _inlineError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFE35D6A),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _canSubmit ? _submit : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(_isSubmitting ? '登录中...' : '进入轻聊'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCredentialSection extends StatelessWidget {
  const _AnimatedCredentialSection({required this.child});

  final Widget child;

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
          child: child,
        ),
      ),
    );
  }
}

class _CredentialSection extends StatelessWidget {
  const _CredentialSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
