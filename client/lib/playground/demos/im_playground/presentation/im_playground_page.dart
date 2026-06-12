import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/playground_api_config.dart';
import '../../../../core/network/dio_factory.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_session_store.dart';
import '../../auth/domain/auth_login_type.dart';
import '../../auth/domain/auth_profile.dart';
import '../../auth/domain/sms_code_info.dart';
import '../../auth/presentation/widgets/auth_login_mode_switch.dart';
import '../data/chat_room_api.dart';
import '../data/chat_room_repository.dart';
import '../domain/chat_room_connection_status.dart';
import '../domain/chat_room_event.dart';
import '../domain/chat_room_message.dart';

class ImPlaygroundPage extends StatefulWidget {
  const ImPlaygroundPage({super.key});

  @override
  State<ImPlaygroundPage> createState() => _ImPlaygroundPageState();
}

class _ImPlaygroundPageState extends State<ImPlaygroundPage> {
  late final AuthRepository _authRepository;
  late final ChatRoomRepository _chatRoomRepository;

  bool _isBootstrapping = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _authRepository = PlaygroundAuthRepository(
      request: DioAuthApi(
        dio: DioFactory.create(baseUrl: PlaygroundApiConfig.defaultBaseUrl),
      ),
      sessionStore: SharedPreferencesAuthSessionStore(),
    );
    _chatRoomRepository = LiveChatRoomRepository(
      request: WebSocketChatRoomApi(),
    );
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final token = await _authRepository.readToken();
    if (!mounted) {
      return;
    }

    setState(() {
      _token = token;
      _isBootstrapping = false;
    });
  }

  Future<void> _handleLogout() async {
    await _chatRoomRepository.disconnect();
    await _authRepository.logout();
    if (!mounted) {
      return;
    }

    setState(() {
      _token = null;
    });
  }

  void _handleLoginSuccess(String token) {
    setState(() {
      _token = token;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF07C160)),
        ),
      );
    }

    if (_token == null || _token!.isEmpty) {
      return _ImLoginView(
        authRepository: _authRepository,
        onLoginSuccess: _handleLoginSuccess,
      );
    }

    return _ImShellView(
      token: _token!,
      authRepository: _authRepository,
      chatRoomRepository: _chatRoomRepository,
      onLogout: _handleLogout,
    );
  }
}

class _ImLoginView extends StatefulWidget {
  const _ImLoginView({
    required this.authRepository,
    required this.onLoginSuccess,
  });

  final AuthRepository authRepository;
  final ValueChanged<String> onLoginSuccess;

  @override
  State<_ImLoginView> createState() => _ImLoginViewState();
}

class _ImLoginViewState extends State<_ImLoginView> {
  static const int _resendCooldownSeconds = 60;

  late final TextEditingController _phoneController;
  late final TextEditingController _codeController;
  late final TextEditingController _accountController;
  late final TextEditingController _passwordController;

  Timer? _countdownTimer;
  bool _isSendingCode = false;
  bool _isSubmitting = false;
  bool _agreed = true;
  AuthLoginType _loginType = AuthLoginType.smsCode;
  int _secondsUntilResend = 0;
  String? _inlineError;
  SmsCodeInfo? _latestSmsCode;

  bool get _canLogin {
    final hasCredentials = switch (_loginType) {
      AuthLoginType.smsCode =>
        _phoneController.text.trim().isNotEmpty &&
            _codeController.text.trim().isNotEmpty,
      AuthLoginType.password =>
        _accountController.text.trim().isNotEmpty &&
            _passwordController.text.trim().isNotEmpty,
    };

    return !_isSubmitting && _agreed && hasCredentials;
  }

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: '13800138000');
    _codeController = TextEditingController();
    _accountController = TextEditingController(text: 'rainy');
    _passwordController = TextEditingController(text: 'rainy123');
    _phoneController.addListener(_onInputChanged);
    _codeController.addListener(_onInputChanged);
    _accountController.addListener(_onInputChanged);
    _passwordController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController
      ..removeListener(_onInputChanged)
      ..dispose();
    _codeController
      ..removeListener(_onInputChanged)
      ..dispose();
    _accountController
      ..removeListener(_onInputChanged)
      ..dispose();
    _passwordController
      ..removeListener(_onInputChanged)
      ..dispose();
    super.dispose();
  }

  void _onInputChanged() {
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
      final info = await widget.authRepository.sendSmsCode(phone);
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

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final account = _accountController.text.trim();
    final password = _passwordController.text.trim();

    if (_loginType == AuthLoginType.smsCode &&
        (phone.isEmpty || code.isEmpty)) {
      setState(() {
        _inlineError = '请输入手机号和验证码';
      });
      return;
    }

    if (_loginType == AuthLoginType.password &&
        (account.isEmpty || password.isEmpty)) {
      setState(() {
        _inlineError = '请输入账号和密码';
      });
      return;
    }

    if (!_agreed) {
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
      final session = switch (_loginType) {
        AuthLoginType.smsCode => await widget.authRepository.loginWithSmsCode(
          phone: phone,
          code: code,
        ),
        AuthLoginType.password => await widget.authRepository.loginWithPassword(
          account: account,
          password: password,
        ),
      };
      if (!mounted) {
        return;
      }
      widget.onLoginSuccess(session.token);
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

  void _handleLoginTypeChanged(AuthLoginType value) {
    if (_loginType == value) {
      return;
    }

    setState(() {
      _loginType = value;
      _inlineError = null;
    });
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

  Widget _buildModeHint() {
    if (_loginType == AuthLoginType.password) {
      return const Padding(
        key: ValueKey('im-password-hint'),
        padding: EdgeInsets.only(top: 10),
        child: Text(
          'playground 体验账号：rainy/rainy123、alice/alice123、bob/bob123',
          style: TextStyle(color: Color(0xFF9FA1AB), fontSize: 11),
        ),
      );
    }

    if (_latestSmsCode == null) {
      return const SizedBox.shrink(key: ValueKey('im-empty-hint'));
    }

    return Padding(
      key: const ValueKey('im-sms-code-hint'),
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'playground 验证码：${_latestSmsCode!.code}',
        style: const TextStyle(color: Color(0xFF9FA1AB), fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
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
                const SizedBox(height: 86),
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
                const SizedBox(height: 24),
                AuthLoginModeSwitch(
                  loginType: _loginType,
                  onChanged: _handleLoginTypeChanged,
                ),
                const SizedBox(height: 54),
                _AnimatedLoginSection(
                  child: _loginType == AuthLoginType.smsCode
                      ? _ImCredentialFields(
                          key: const ValueKey('im-sms-code-fields'),
                          children: [
                            _UnderlineInputRow(
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
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _UnderlineInputRow(
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
                                  ),
                                  suffixIconConstraints: const BoxConstraints(
                                    minWidth: 56,
                                    minHeight: 24,
                                  ),
                                  suffixIcon: _SendCodeAction(
                                    isSendingCode: _isSendingCode,
                                    secondsUntilResend: _secondsUntilResend,
                                    onTap: _sendCode,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _ImCredentialFields(
                          key: const ValueKey('im-password-fields'),
                          children: [
                            _UnderlineInputRow(
                              leading: const Text(
                                '账号',
                                style: TextStyle(
                                  color: Color(0xFF17171F),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: TextField(
                                controller: _accountController,
                                style: const TextStyle(
                                  color: Color(0xFF17171F),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '请输入账号，例如 rainy',
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintStyle: TextStyle(
                                    color: Color(0xFFB1B2BA),
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _UnderlineInputRow(
                              leading: const Text(
                                '密码',
                                style: TextStyle(
                                  color: Color(0xFF17171F),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: TextField(
                                controller: _passwordController,
                                obscureText: true,
                                style: const TextStyle(
                                  color: Color(0xFF17171F),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '请输入密码',
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintStyle: TextStyle(
                                    color: Color(0xFFB1B2BA),
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: const Offset(-10, -8),
                      child: Checkbox(
                        value: _agreed,
                        side: const BorderSide(color: Color(0xFFD6D8DE)),
                        activeColor: const Color(0xFF6B8FF8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _agreed = value ?? false;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
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
                            TextSpan(
                              text: _loginType == AuthLoginType.smsCode
                                  ? '，未注册绑定的手机号验证成功后将自动注册'
                                  : '，password 模式使用内置体验账号即可进入',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                _AnimatedLoginHintSection(child: _buildModeHint()),
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
                      foregroundColor: const Color(0xFF6B6E76),
                      disabledForegroundColor: const Color(0xFFC5C7CD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF07C160),
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

class _AnimatedLoginSection extends StatelessWidget {
  const _AnimatedLoginSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
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
        layoutBuilder: (currentChild, previousChildren) {
          return AnimatedSize(
            duration: const Duration(milliseconds: 260),
            reverseDuration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
          );
        },
        child: child,
      ),
    );
  }
}

class _AnimatedLoginHintSection extends StatelessWidget {
  const _AnimatedLoginHintSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _ImCredentialFields extends StatelessWidget {
  const _ImCredentialFields({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _ImShellView extends StatefulWidget {
  const _ImShellView({
    required this.token,
    required this.authRepository,
    required this.chatRoomRepository,
    required this.onLogout,
  });

  final String token;
  final AuthRepository authRepository;
  final ChatRoomRepository chatRoomRepository;
  final Future<void> Function() onLogout;

  @override
  State<_ImShellView> createState() => _ImShellViewState();
}

class _ImShellViewState extends State<_ImShellView> {
  int _currentIndex = 0;
  late Future<AuthProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.authRepository.fetchProfile();
  }

  Future<void> _reloadProfile() async {
    final future = widget.authRepository.fetchProfile();
    setState(() {
      _profileFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF4F4F4),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF07C160)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF666666)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: widget.onLogout,
                      child: const Text('返回登录'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.requireData;
        final pages = <Widget>[
          _ChatRoomView(
            token: widget.token,
            currentUser: profile,
            repository: widget.chatRoomRepository,
          ),
          _MyTabView(
            profile: profile,
            onLogout: widget.onLogout,
            onReload: _reloadProfile,
          ),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F4),
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF07C160),
            unselectedItemColor: const Color(0xFF303133),
            selectedFontSize: 14,
            unselectedFontSize: 14,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: _BottomBarBadge(
                  label: '15',
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                activeIcon: _BottomBarBadge(
                  label: '15',
                  child: const Icon(Icons.chat_bubble_rounded),
                ),
                label: '聊天室',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: '我',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatRoomView extends StatefulWidget {
  const _ChatRoomView({
    required this.token,
    required this.currentUser,
    required this.repository,
  });

  final String token;
  final AuthProfile currentUser;
  final ChatRoomRepository repository;

  @override
  State<_ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<_ChatRoomView> {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  late final List<ChatRoomMessage> _messages;

  StreamSubscription<ChatRoomEvent>? _subscription;
  Timer? _heartbeatTimer;
  ChatRoomConnectionStatus _status = ChatRoomConnectionStatus.disconnected;

  bool get _hasInput => _messageController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _messages = widget.repository.buildSeedMessages(
      currentUser: widget.currentUser,
    );
    _messageController.addListener(_handleInputChanged);
    _connect();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(widget.repository.disconnect());
    _messageController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _connect() {
    _subscription = widget.repository
        .connect(
          baseUrl: PlaygroundApiConfig.defaultBaseUrl,
          token: widget.token,
          currentUserId: widget.currentUser.userId,
        )
        .listen(_handleEvent);
  }

  void _handleEvent(ChatRoomEvent event) {
    if (!mounted) {
      return;
    }

    switch (event.type) {
      case ChatRoomEventType.status:
        setState(() {
          _status = event.status!;
        });
        if (_status == ChatRoomConnectionStatus.connected) {
          _startHeartbeat();
        } else {
          _heartbeatTimer?.cancel();
        }
      case ChatRoomEventType.message:
        setState(() {
          _messages.add(event.message!);
        });
        _scrollToBottom();
      case ChatRoomEventType.error:
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(content: Text(event.errorMessage ?? '聊天室连接异常')),
        );
      case ChatRoomEventType.pong:
        break;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 18), (timer) {
      widget.repository.sendHeartbeat();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _messageController.clear();
    await widget.repository.sendChat(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEFEF),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 52,
              color: const Color(0xFFF8F8F8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const SizedBox(width: 28),
                  const Spacer(),
                  const Text(
                    '汪萱',
                    style: TextStyle(
                      color: Color(0xFF181818),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF222222),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _ChatMessageItem(message: message);
                },
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F8F8),
                border: Border(top: BorderSide(color: Color(0xFFE1E1E1))),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.keyboard_voice_outlined,
                        size: 28,
                        color: Color(0xFF202020),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _messageController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '输入消息',
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.emoji_emotions_outlined,
                        size: 30,
                        color: Color(0xFF202020),
                      ),
                      const SizedBox(width: 8),
                      _hasInput
                          ? GestureDetector(
                              onTap: _sendMessage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF07C160),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '发送',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 32,
                              color: Color(0xFF202020),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyTabView extends StatelessWidget {
  const _MyTabView({
    required this.profile,
    required this.onLogout,
    required this.onReload,
  });

  final AuthProfile profile;
  final Future<void> Function() onLogout;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final wechatId =
        'tallowjacky${profile.userId}${profile.phone.substring(7)}';

    return Container(
      color: const Color(0xFFF3F3F3),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 26),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        profile.avatarUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile.nickname}～',
                            style: const TextStyle(
                              color: Color(0xFF171717),
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '微信号：$wechatId',
                            style: const TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ProfileChip(
                                label: '+ 状态',
                                color: const Color(0xFF707070),
                              ),
                              const _ProfileChip(
                                label: '等8个朋友',
                                color: Color(0xFF707070),
                                showDot: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: const [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Color(0xFF6C7DA8),
                        ),
                        SizedBox(height: 18),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFB0B0B0),
                          size: 30,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _MyCellGroup(
                children: [
                  _MyCellData(
                    icon: Icons.verified_user_outlined,
                    iconColor: Color(0xFF07C160),
                    title: '服务',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _MyCellGroup(
                children: [
                  _MyCellData(
                    icon: Icons.inventory_2_outlined,
                    iconColor: Color(0xFFFFB020),
                    title: '收藏',
                  ),
                  _MyCellData(
                    icon: Icons.photo_outlined,
                    iconColor: Color(0xFF2D8CFF),
                    title: '朋友圈',
                  ),
                  _MyCellData(
                    icon: Icons.play_circle_outline_rounded,
                    iconColor: Color(0xFFFF9C2F),
                    title: '视频号',
                  ),
                  _MyCellData(
                    icon: Icons.storefront_outlined,
                    iconColor: Color(0xFFFF6B57),
                    title: '订单与卡包',
                  ),
                  _MyCellData(
                    icon: Icons.emoji_emotions_outlined,
                    iconColor: Color(0xFFFFC107),
                    title: '表情',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _MyCellGroup(
                children: [
                  _MyCellData(
                    icon: Icons.settings_outlined,
                    iconColor: Color(0xFF2D8CFF),
                    title: '设置',
                    showDot: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReload,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: Color(0xFFDADADA)),
                          foregroundColor: const Color(0xFF444444),
                        ),
                        child: const Text('刷新资料'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onLogout,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: Color(0xFFE35D5D)),
                          foregroundColor: const Color(0xFFE35D5D),
                        ),
                        child: const Text('退出登录'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnderlineInputRow extends StatelessWidget {
  const _UnderlineInputRow({required this.leading, required this.child});

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

class _SendCodeAction extends StatelessWidget {
  const _SendCodeAction({
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
            color: Color(0xFF07C160),
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

class _ChatMessageItem extends StatelessWidget {
  const _ChatMessageItem({required this.message});

  final ChatRoomMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatRoomMessageKind.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            message.text ?? '',
            style: const TextStyle(color: Color(0xFF9D9D9D), fontSize: 12),
          ),
        ),
      );
    }

    final bubble = switch (message.kind) {
      ChatRoomMessageKind.text => _TextBubble(
        text: message.text ?? '',
        isCurrentUser: message.isCurrentUser,
      ),
      ChatRoomMessageKind.image => _ImageBubble(
        imageUrl: message.imageUrl ?? '',
      ),
      ChatRoomMessageKind.transfer => _TransferBubble(
        amountLabel: message.amountLabel ?? '',
        transferStatus: message.transferStatus ?? '',
        footerLabel: message.footerLabel ?? '',
        isCurrentUser: message.isCurrentUser,
      ),
      ChatRoomMessageKind.system => const SizedBox.shrink(),
    };

    if (message.isCurrentUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(child: bubble),
            const SizedBox(width: 10),
            _AvatarBox(imageUrl: message.senderAvatarUrl),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarBox(imageUrl: message.senderAvatarUrl),
          const SizedBox(width: 10),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.text, required this.isCurrentUser});

  final String text;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFF95EC69) : Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF171717),
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        imageUrl,
        width: 210,
        height: 260,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _TransferBubble extends StatelessWidget {
  const _TransferBubble({
    required this.amountLabel,
    required this.transferStatus,
    required this.footerLabel,
    required this.isCurrentUser,
  });

  final String amountLabel;
  final String transferStatus;
  final String footerLabel;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE1BF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amountLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    transferStatus,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0x33FFFFFF), height: 1),
          const SizedBox(height: 10),
          Text(
            footerLabel,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AvatarBox extends StatelessWidget {
  const _AvatarBox({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(imageUrl, width: 40, height: 40, fit: BoxFit.cover),
    );
  }
}

class _BottomBarBadge extends StatelessWidget {
  const _BottomBarBadge({required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -6,
          right: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D4F),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.label,
    required this.color,
    this.showDot = false,
  });

  final String label;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCECECE)),
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showDot) ...[
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFFF4D4F),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MyCellGroup extends StatelessWidget {
  const _MyCellGroup({required this.children});

  final List<_MyCellData> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: List<Widget>.generate(children.length, (index) {
          final item = children[index];
          return Column(
            children: [
              _MyCell(item: item),
              // if (index != children.length - 1)
              //   const Divider(height: 1, indent: 72, endIndent: 0),
            ],
          );
        }),
      ),
    );
  }
}

class _MyCellData {
  const _MyCellData({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.showDot = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final bool showDot;
}

class _MyCell extends StatelessWidget {
  const _MyCell({required this.item});

  final _MyCellData item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Icon(item.icon, color: item.iconColor, size: 28),
          const SizedBox(width: 18),
          Text(
            item.title,
            style: const TextStyle(
              color: Color(0xFF171717),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (item.showDot) ...[
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFFF4D4F),
                shape: BoxShape.circle,
              ),
            ),
          ],
          const Spacer(),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFB8B8B8),
            size: 30,
          ),
        ],
      ),
    );
  }
}
