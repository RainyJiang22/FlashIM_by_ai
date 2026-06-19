import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/app_router.dart';
import 'widgets/mine_error_view.dart';
import 'widgets/mine_info_card.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<SessionCubit>().refreshProfile();
    });
  }

  Future<void> _reload() async {
    await context.read<SessionCubit>().refreshProfile();
  }

  Future<void> _logout() async {
    await context.read<SessionCubit>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionCubit, SessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == SessionStatus.unauthenticated,
      listener: (context, state) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      },
      builder: (context, state) {
        final user = state.user;
        if (user == null) {
          if (state.errorMessage != null) {
            return MineErrorView(message: state.errorMessage!, onRetry: _reload);
          }
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              UserCard(
                user: user,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
              ),
              const SizedBox(height: 24),
              MineInfoCard(
                user: user,
                onPasswordTap: () => Navigator.of(context).pushNamed(
                  user.hasPassword
                      ? AppRoutes.changePassword
                      : AppRoutes.setPassword,
                ),
              ),
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
    );
  }
}
