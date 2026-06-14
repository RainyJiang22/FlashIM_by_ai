import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/app_router.dart';
import '../../cubit/app_session_cubit.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_profile.dart';
import '../../domain/auth_status.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  late Future<AuthProfile> _profileFuture;

  AppSessionCubit get _sessionCubit => context.read<AppSessionCubit>();
  AuthRepository get _repository => context.read<AuthRepository>();

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<AuthProfile> _loadProfile() async {
    try {
      final profile = await _repository.fetchProfile();
      _sessionCubit.syncProfile(profile);
      return profile;
    } on AuthMissingTokenException {
      await _sessionCubit.logout();
      rethrow;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _sessionCubit.logout();
      }
      rethrow;
    }
  }

  Future<void> _reload() async {
    final future = _loadProfile();
    setState(() {
      _profileFuture = future;
    });
    await future;
  }

  Future<void> _logout() async {
    await _sessionCubit.logout();
  }

  String _readErrorMessage(Object error) {
    if (error is AuthMissingTokenException) {
      return '登录态缺失，请重新登录';
    }
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map && payload['message'] is String) {
        return payload['message'] as String;
      }
      if (error.response?.statusCode == 401) {
        return '登录态已失效，请重新登录';
      }
      return error.message ?? '个人信息加载失败';
    }
    return '个人信息加载失败';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppSessionCubit, AppSessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == AuthStatus.unauthenticated,
      listener: (context, state) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      },
      child: FutureBuilder<AuthProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MeErrorView(
              message: _readErrorMessage(snapshot.error!),
              onRetry: _reload,
            );
          }

          final profile = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color(0xFFEAF1FF),
                  backgroundImage: NetworkImage(profile.avatarUrl),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    profile.nickname,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2A42),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    profile.phone,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6A7B92),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _MeInfoCard(profile: profile),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: const Color(0xFF1C4EFF),
                      side: const BorderSide(color: Color(0xFFD5E2F3)),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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

class _MeInfoCard extends StatelessWidget {
  const _MeInfoCard({required this.profile});

  final AuthProfile profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x101C4EFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(label: '账户 ID', value: profile.accountId.toString()),
          const Divider(height: 1),
          _InfoRow(label: '昵称', value: profile.nickname),
          const Divider(height: 1),
          _InfoRow(label: '手机号', value: profile.phone),
          const Divider(height: 1),
          _InfoRow(label: '密码状态', value: profile.hasPassword ? '已设置' : '未设置'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6A7B92)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2A42),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeErrorView extends StatelessWidget {
  const _MeErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
