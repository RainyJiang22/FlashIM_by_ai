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
  int _secondsUntilResend = 0;
  String? _inlineError;
  SmsCodeInfo? _latestSmsCode;

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
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
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

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (phone.isEmpty || code.isEmpty) {
      setState(() {
        _inlineError = '请输入手机号和验证码。';
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
        _inlineError = '请先输入手机号。';
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
      return error.message ?? '请求失败，请稍后重试。';
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const _AuthNebulaBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _isBootstrapping
                      ? const _AuthLoadingView()
                      : _AuthLoginPanel(
                          phoneController: _phoneController,
                          codeController: _codeController,
                          isSendingCode: _isSendingCode,
                          isSubmitting: _isSubmitting,
                          secondsUntilResend: _secondsUntilResend,
                          latestSmsCode: _latestSmsCode,
                          inlineError: _inlineError,
                          onSendCode: _sendCode,
                          onLogin: _login,
                          theme: theme,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthLoginPanel extends StatelessWidget {
  const _AuthLoginPanel({
    required this.phoneController,
    required this.codeController,
    required this.isSendingCode,
    required this.isSubmitting,
    required this.secondsUntilResend,
    required this.latestSmsCode,
    required this.inlineError,
    required this.onSendCode,
    required this.onLogin,
    required this.theme,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool isSendingCode;
  final bool isSubmitting;
  final int secondsUntilResend;
  final SmsCodeInfo? latestSmsCode;
  final String? inlineError;
  final VoidCallback onSendCode;
  final VoidCallback onLogin;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final canSendCode = !isSendingCode && secondsUntilResend == 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCC121A29), Color(0xE6120F1B), Color(0xF0131625)],
        ),
        border: Border.all(color: const Color(0xFF31405B)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 38,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _AuthLabelChip(label: 'playground'),
                _AuthLabelChip(label: '用户认证'),
                _AuthLabelChip(label: '验证码登录'),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              '把登录链路先做对，再谈 IM 的下一步。',
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '这个模块用于演示手机号 + 验证码登录、Token 持久化、自动鉴权和退出登录。界面保持克制，但不走廉价拼装风。',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFFADB7CC),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),
            _AuthFieldShell(
              child: TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: '手机号',
                  hintText: '请输入手机号',
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _AuthFieldShell(
                    child: TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: '验证码',
                        hintText: '请输入 6 位验证码',
                        prefixIcon: Icon(Icons.shield_moon_outlined),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: FilledButton(
                    onPressed: canSendCode ? onSendCode : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(62),
                      backgroundColor: const Color(0xFFE7F0FF),
                      foregroundColor: const Color(0xFF0E1C35),
                      disabledBackgroundColor: const Color(0xFF36445D),
                      disabledForegroundColor: const Color(0xFF9EABC0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: isSendingCode
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            secondsUntilResend > 0
                                ? '${secondsUntilResend}s 后重发'
                                : '发送验证码',
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (latestSmsCode != null)
              _AuthCodePreviewCard(
                code: latestSmsCode!.code,
                phone: latestSmsCode!.phone,
              ),
            if (latestSmsCode != null) const SizedBox(height: 14),
            if (inlineError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  inlineError!,
                  style: const TextStyle(
                    color: Color(0xFFFFB4B4),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : onLogin,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_outward_rounded),
                label: Text(isSubmitting ? '登录中...' : '进入个人信息页'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  backgroundColor: const Color(0xFF6EF7C8),
                  foregroundColor: const Color(0xFF052116),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _AuthFootnote(),
          ],
        ),
      ),
    );
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD5121723),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF2C3951)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF6EF7C8)),
            SizedBox(height: 18),
            Text(
              '正在恢复登录状态...',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFootnote extends StatelessWidget {
  const _AuthFootnote();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        _AuthMiniNote(icon: Icons.timer_outlined, label: '验证码 60 秒冷却'),
        _AuthMiniNote(icon: Icons.lock_outline_rounded, label: '登录成功自动持久化 Token'),
        _AuthMiniNote(icon: Icons.badge_outlined, label: '资料页自动携带鉴权头'),
      ],
    );
  }
}

class _AuthMiniNote extends StatelessWidget {
  const _AuthMiniNote({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF171F30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2E3B56)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF8FE8CB), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFBDC6D8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthCodePreviewCard extends StatelessWidget {
  const _AuthCodePreviewCard({required this.code, required this.phone});

  final String code;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x1213F0B9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF295042)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              color: Color(0xFF8FF0CC),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'playground 验证码',
                    style: TextStyle(
                      color: Color(0xFFB9C4D7),
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              phone,
              style: const TextStyle(color: Color(0xFF90A0B8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFieldShell extends StatelessWidget {
  const _AuthFieldShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF131A28),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2D3952)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(color: Color(0xFF94A2B8)),
              hintStyle: TextStyle(color: Color(0xFF4F5D77)),
              prefixIconColor: Color(0xFF7F90A9),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AuthLabelChip extends StatelessWidget {
  const _AuthLabelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF171D2C),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2E3B56)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCAD3E5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _AuthNebulaBackground extends StatelessWidget {
  const _AuthNebulaBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060913), Color(0xFF09101B), Color(0xFF121420)],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -100,
            left: -40,
            child: _GlowOrb(
              size: 280,
              color: Color(0x33A9FFF1),
            ),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: _GlowOrb(
              size: 240,
              color: Color(0x2FFF9C6B),
            ),
          ),
          Positioned(
            bottom: -80,
            left: 40,
            child: _GlowOrb(
              size: 260,
              color: Color(0x1F7D8CFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: size * 0.4)],
        ),
      ),
    );
  }
}
