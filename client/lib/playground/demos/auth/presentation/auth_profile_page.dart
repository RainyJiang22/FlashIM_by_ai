import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../domain/auth_profile.dart';
import 'auth_playground_page.dart';

class AuthProfilePage extends StatefulWidget {
  const AuthProfilePage({super.key, required AuthRepository repository})
    : _repository = repository;

  final AuthRepository _repository;

  @override
  State<AuthProfilePage> createState() => _AuthProfilePageState();
}

class _AuthProfilePageState extends State<AuthProfilePage> {
  late Future<_AuthProfileViewData> _profileFuture;

  AuthRepository get _repository => widget._repository;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileViewData();
  }

  Future<void> _logout() async {
    await _repository.logout();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AuthPlaygroundPage(repository: _repository),
      ),
    );
  }

  Future<void> _reload() async {
    final future = _loadProfileViewData();
    setState(() {
      _profileFuture = future;
    });
    await future;
  }

  Future<_AuthProfileViewData> _loadProfileViewData() async {
    final token = await _repository.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthMissingTokenException();
    }

    final profile = await _repository.fetchProfile();
    return _AuthProfileViewData(profile: profile, token: token);
  }

  Future<void> _returnToLoginWithLogout() async {
    await _repository.logout();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AuthPlaygroundPage(repository: _repository),
      ),
    );
  }

  String _readErrorMessage(Object error) {
    if (error is AuthMissingTokenException) {
      return '本地没有可用的 Token，请重新登录。';
    }

    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return '登录态已失效，请重新登录。';
      }
      final payload = error.response?.data;
      if (payload is Map && payload['message'] is String) {
        return payload['message'] as String;
      }
      return error.message ?? '个人信息加载失败。';
    }

    return error.toString();
  }

  bool _shouldForceLogout(Object error) {
    if (error is AuthMissingTokenException) {
      return true;
    }
    return error is DioException && error.response?.statusCode == 401;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF08111A), Color(0xFF111827), Color(0xFF08131F)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: FutureBuilder<_AuthProfileViewData>(
                    future: _profileFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6EF7C8),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        final error = snapshot.error!;
                        return _AuthProfileErrorView(
                          message: _readErrorMessage(error),
                          actionLabel: _shouldForceLogout(error)
                              ? '返回登录页'
                              : '重试',
                          onPressed: _shouldForceLogout(error)
                              ? _returnToLoginWithLogout
                              : _reload,
                        );
                      }

                      final viewData = snapshot.requireData;
                      final profile = viewData.profile;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xE1162032),
                                  Color(0xF0101726),
                                  Color(0xE3151520),
                                ],
                              ),
                              border: Border.all(color: const Color(0xFF30415D)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x52000000),
                                  blurRadius: 42,
                                  offset: Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF7FF0D0),
                                            width: 2,
                                          ),
                                          image: DecorationImage(
                                            image: NetworkImage(profile.avatarUrl),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              profile.nickname,
                                              style: theme
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            const _ProfileTag(
                                              label: '资料来自 /user/profile',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  _ProfileInfoRow(
                                    label: '用户 ID',
                                    value: profile.userId.toString(),
                                  ),
                                  const SizedBox(height: 12),
                                  _ProfileInfoRow(
                                    label: '手机号',
                                    value: profile.phone,
                                  ),
                                  const SizedBox(height: 12),
                                  _ProfileInfoRow(
                                    label: '头像 URL',
                                    value: profile.avatarUrl,
                                    selectable: true,
                                  ),
                                  const SizedBox(height: 12),
                                  _ProfileInfoRow(
                                    label: 'JWT Token',
                                    value: viewData.token,
                                    selectable: true,
                                    monospace: true,
                                  ),
                                  const SizedBox(height: 12),
                                  const _ProfileInfoRow(
                                    label: '登录状态',
                                    value: 'Token 已保存，后续请求自动携带 Authorization',
                                  ),
                                  const SizedBox(height: 24),
                                  LayoutBuilder(
                                    builder: (context, actionConstraints) {
                                      final useColumn =
                                          actionConstraints.maxWidth < 420;
                                      if (useColumn) {
                                        return Column(
                                          children: [
                                            SizedBox(
                                              width: double.infinity,
                                              child: _RefreshButton(
                                                onPressed: _reload,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: _LogoutButton(
                                                onPressed: _logout,
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          Expanded(
                                            child: _RefreshButton(
                                              onPressed: _reload,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _LogoutButton(
                                              onPressed: _logout,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthProfileViewData {
  const _AuthProfileViewData({required this.profile, required this.token});

  final AuthProfile profile;
  final String token;
}

class _AuthProfileErrorView extends StatelessWidget {
  const _AuthProfileErrorView({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xD1121926),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF33435E)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFFFC1AE),
                  size: 34,
                ),
                const SizedBox(height: 14),
                const Text(
                  '个人信息加载失败',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB5C0D3),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onPressed,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool selectable;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E3E59)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8FA0B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: selectable
                  ? SelectableText(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.45,
                        fontFamily: monospace ? 'monospace' : null,
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.45,
                        fontFamily: monospace ? 'monospace' : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('刷新资料'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF435271)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded),
      label: const Text('退出登录'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: const Color(0xFFFFD4C8),
        foregroundColor: const Color(0xFF32120B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x1429F0B5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2B5747)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF93EFD2),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
