import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/playground_api_config.dart';
import '../../../../core/network/dio_factory.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../data/auth_session_store.dart';
import '../domain/sms_code_info.dart';
import 'auth_profile_page.dart';

class AuthPlaygroundPage extends StatefulWidget {
  const AuthPlaygroundPage({super.key, AuthRepository? repository})
    : _repository = repository;

  final AuthRepository? _repository;

  @override
  State<AuthPlaygroundPage> createState() => _AuthPlaygroundPageState();
}

class _AuthPlaygroundPageState extends State<AuthPlaygroundPage> {
  static const int _resendCooldownSeconds = 60;

  late final AuthRepository _repository;
  late final TextEditingController _phoneController;
  late final TextEditingController _codeController;

  Timer? _countdownTimer;
  bool _isBootstrapping = true;
  bool _isSendingCode = false;
  bool _isSubmitting = false;
  bool _agreedToTerms = true;
  int _secondsUntilResend = 0;
  String? _inlineError;
  SmsCodeInfo? _latestSmsCode;

  bool get _canLogin {
    return !_isSubmitting &&
        _agreedToTerms &&
        _phoneController.text.trim().isNotEmpty &&
        _codeController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _repository =
        widget._repository ??
        PlaygroundAuthRepository(
          request: DioAuthApi(
            dio: DioFactory.create(baseUrl: PlaygroundApiConfig.defaultBaseUrl),
          ),
          sessionStore: SharedPreferencesAuthSessionStore(),
        );
    _phoneController = TextEditingController(text: '13800138000');
    _codeController = TextEditingController();
    _phoneController.addListener(_handleInputChanged);
    _codeController.addListener(_handleInputChanged);
    unawaited(_bootstrap());
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
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _repository.readToken();
    if (!mounted) {
      return;
    }

    if (token != null && token.isNotEmpty) {
      _openProfile();
      return;
    }

    setState(() {
      _isBootstrapping = false;
    });
  }

  void _handleInputChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (phone.isEmpty || code.isEmpty) {
      setState(() {
        _inlineError = '请输入手机号和验证码';
      });
      return;
    }

    if (!_agreedToTerms) {
      setState(() {
        _inlineError = '请先勾选协议';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      await _repository.login(phone: phone, code: code);
      if (!mounted) {
        return;
      }
      _openProfile();
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

  void _openProfile() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AuthProfilePage(repository: _repository),
      ),
    );
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
      final info = await _repository.sendSmsCode(phone);
      if (!mounted) {
        return;
      }

      _codeController.text = info.code;
      _codeController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: info.code.length,
      );
      setState(() {
        _latestSmsCode = info;
      });
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

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsUntilResend = _resendCooldownSeconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() {
          _secondsUntilResend = 0;
        });
        return;
      }

      setState(() {
        _secondsUntilResend -= 1;
      });
    });
  }

  String _readErrorMessage(Object error) {
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map && payload['message'] is String) {
        return payload['message'] as String;
      }
      return error.message ?? '请求失败，请稍后重试';
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isBootstrapping
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6B8FF8)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 28,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 130),
                      const Center(
                        child: Text(
                          'FLASH IM',
                          style: TextStyle(
                            color: Color(0xFF17171F),
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          '即 时 通 信 练 习 场',
                          style: TextStyle(
                            color: Color(0xFF8A8A95),
                            fontSize: 12,
                            letterSpacing: 3.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 58),
                      _AuthUnderlineField(
                        leading: const Text(
                          '+86',
                          style: TextStyle(
                            color: Color(0xFF17171F),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            color: Color(0xFF17171F),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            hintText: '请输入手机号',
                            border: InputBorder.none,
                            isDense: true,
                            hintStyle: TextStyle(
                              color: Color(0xFFB1B2BA),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AuthUnderlineField(
                        leading: const Text(
                          '验证码',
                          style: TextStyle(
                            color: Color(0xFF17171F),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Color(0xFF17171F),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: '请输入 6 位验证码',
                            border: InputBorder.none,
                            isDense: true,
                            hintStyle: const TextStyle(
                              color: Color(0xFFB1B2BA),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 56,
                              minHeight: 24,
                            ),
                            suffixIcon: _AuthCountdownAction(
                              isSendingCode: _isSendingCode,
                              secondsUntilResend: _secondsUntilResend,
                              onTap: _sendCode,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: const Offset(-10, -8),
                            child: Checkbox(
                              value: _agreedToTerms,
                              side: const BorderSide(color: Color(0xFFD6D8DE)),
                              activeColor: const Color(0xFF6B8FF8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _agreedToTerms = value ?? false;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  color: Color(0xFF8F9097),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(text: '登录即代表您同意 '),
                                  TextSpan(
                                    text: '《用户协议》',
                                    style: TextStyle(
                                      color: Color(0xFF6B8FF8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: ' 和 '),
                                  TextSpan(
                                    text: '《隐私政策》',
                                    style: TextStyle(
                                      color: Color(0xFF6B8FF8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: '，未注册绑定的手机号验证成功后将自动注册'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_latestSmsCode != null) const SizedBox(height: 10),
                      if (_latestSmsCode != null)
                        Text(
                          'playground 验证码：${_latestSmsCode!.code}',
                          style: const TextStyle(
                            color: Color(0xFF9FA1AB),
                            fontSize: 11,
                          ),
                        ),
                      if (_inlineError != null) const SizedBox(height: 10),
                      if (_inlineError != null)
                        Text(
                          _inlineError!,
                          style: const TextStyle(
                            color: Color(0xFFE25B5B),
                            fontSize: 11,
                          ),
                        ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _canLogin ? _login : null,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: BorderSide(
                              color: _canLogin
                                  ? const Color(0xFFD2D4DA)
                                  : const Color(0xFFE9E9EE),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            foregroundColor: const Color(0xFF6B6E76),
                            disabledForegroundColor: const Color(0xFFC5C7CD),
                            backgroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 5,
                                    color: Color(0xFF6B8FF8),
                                  ),
                                )
                              : const Text('登录'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _AuthUnderlineField extends StatelessWidget {
  const _AuthUnderlineField({required this.leading, required this.child});

  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE9E9EE), width: 1.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 84, child: leading),
            Container(width: 1.5, height: 24, color: const Color(0xFFD5E1FF)),
            const SizedBox(width: 14),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _AuthCountdownAction extends StatelessWidget {
  const _AuthCountdownAction({
    required this.isSendingCode,
    required this.secondsUntilResend,
    required this.onTap,
  });

  final bool isSendingCode;
  final int secondsUntilResend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isSendingCode) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF6B8FF8),
          ),
        ),
      );
    }

    if (secondsUntilResend > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${secondsUntilResend}s',
          style: const TextStyle(
            color: Color(0xFFB6B8BF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        '发送',
        style: TextStyle(
          color: Color(0xFF6B8FF8),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
