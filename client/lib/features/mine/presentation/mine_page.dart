import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/app_router.dart';
import '../../auth/cubit/app_session_cubit.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_profile.dart';
import '../../auth/domain/auth_status.dart';
import 'widgets/mine_error_view.dart';
import 'widgets/mine_info_card.dart';
import 'widgets/mine_profile_header.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
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
            return MineErrorView(
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
                MineProfileHeader(profile: profile),
                const SizedBox(height: 24),
                MineInfoCard(profile: profile),
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
