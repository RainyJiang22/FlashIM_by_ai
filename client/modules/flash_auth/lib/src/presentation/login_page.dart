import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';
import '../domain/app_session.dart';
import '../domain/login_method.dart';
import 'widgets/auth_login_form_card.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.homeRouteName,
    required this.onLoginSuccess,
  });

  final String homeRouteName;
  final Future<void> Function(AppSession session) onLoginSuccess;

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
      await widget.onLoginSuccess(session);
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(widget.homeRouteName, (route) => false);
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AuthLoginFormCard(
                method: _method,
                phoneController: _phoneController,
                codeController: _codeController,
                passwordController: _passwordController,
                inlineError: _inlineError,
                isSendingCode: _isSendingCode,
                cooldownSeconds: _cooldownSeconds,
                isSubmitting: _isSubmitting,
                canSubmit: _canSubmit,
                onMethodChanged: (value) {
                  if (_method == value) {
                    return;
                  }
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _method = value;
                    _inlineError = null;
                  });
                },
                onSendCode: _sendCode,
                onSubmit: _submit,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
