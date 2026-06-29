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
            return MineErrorView(
              message: state.errorMessage!,
              onRetry: _reload,
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _reload,
          color: const Color(0xFF07C160),
          child: ColoredBox(
            color: const Color(0xFFF1F1F1),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 18),
                UserCard(
                  user: user,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.editProfile),
                ),
                const SizedBox(height: 10),
                MineInfoCard(
                  user: user,
                  onPasswordTap: () => Navigator.of(context).pushNamed(
                    user.hasPassword
                        ? AppRoutes.changePassword
                        : AppRoutes.setPassword,
                  ),
                  onLogout: _logout,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}
