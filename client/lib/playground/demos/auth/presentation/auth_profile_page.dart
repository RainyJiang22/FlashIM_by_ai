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

  Future<_AuthProfileViewData> _loadProfileViewData() async {
    final token = await _repository.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthMissingTokenException();
    }

    final profile = await _repository.fetchProfile();
    return _AuthProfileViewData(profile: profile, token: token);
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
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCDBBFF),
        surfaceTintColor: const Color(0xFFCDBBFF),
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 76,
        titleSpacing: 18,
        title: const Text(
          '个人信息',
          style: TextStyle(
            color: Color(0xFF17171F),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: FutureBuilder<_AuthProfileViewData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8D6CF6)),
            );
          }

          if (snapshot.hasError) {
            final error = snapshot.error!;
            return _AuthProfileErrorView(
              message: _readErrorMessage(error),
              actionLabel: _shouldForceLogout(error) ? '返回登录页' : '重试',
              onPressed: _shouldForceLogout(error)
                  ? _returnToLoginWithLogout
                  : _reload,
            );
          }

          final viewData = snapshot.requireData;
          final profile = viewData.profile;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFFE8DDFF),
                  backgroundImage: NetworkImage(profile.avatarUrl),
                ),
                const SizedBox(height: 18),
                Text(
                  profile.phone,
                  style: const TextStyle(
                    color: Color(0xFF17171F),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ID: ${profile.userId}',
                  style: const TextStyle(
                    color: Color(0xFFB2AEB9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                _ProfileSummaryCard(profile: profile),
                const SizedBox(height: 18),
                _TokenCard(token: viewData.token),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      side: const BorderSide(
                        color: Color(0xFFE35D5D),
                        width: 1.4,
                      ),
                      foregroundColor: const Color(0xFFE35D5D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('退出登录'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AuthProfileViewData {
  const _AuthProfileViewData({required this.profile, required this.token});

  final AuthProfile profile;
  final String token;
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profile});

  final AuthProfile profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _ProfileSummaryRow(
            icon: Icons.phone_in_talk_rounded,
            label: '手机号',
            value: profile.phone,
          ),
          const Divider(height: 1, indent: 68, endIndent: 18),
          _ProfileSummaryRow(
            icon: Icons.person_rounded,
            label: '昵称',
            value: profile.nickname,
          ),
          const Divider(height: 1, indent: 68, endIndent: 18),
          _ProfileSummaryRow(
            icon: Icons.badge_rounded,
            label: '用户 ID',
            value: profile.userId.toString(),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryRow extends StatelessWidget {
  const _ProfileSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(icon, color: const Color(0xFF7354D5), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9D9AA7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF2C2934),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'JWT Token',
              style: TextStyle(
                color: Color(0xFF6E6B76),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              token,
              style: const TextStyle(
                color: Color(0xFF66636E),
                fontSize: 12,
                height: 1.55,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFE35D5D),
                  size: 36,
                ),
                const SizedBox(height: 14),
                const Text(
                  '个人信息加载失败',
                  style: TextStyle(
                    color: Color(0xFF2B2833),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF86838C),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6CF6),
                    foregroundColor: Colors.white,
                  ),
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
