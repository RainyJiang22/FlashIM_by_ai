import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/app_router.dart';
import '../../auth/cubit/app_session_cubit.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_status.dart';
import '../../mine/presentation/dialogs/password_setup_prompt_dialog.dart';
import '../../mine/presentation/mine_page.dart';
import '../../contacts/presentation/contacts_placeholder_page.dart';
import '../../messages/presentation/messages_placeholder_page.dart';
import 'widgets/home_navigation_bar.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;
  bool _isShowingPasswordPrompt = false;

  static const List<Widget> _pages = <Widget>[
    MessagesPlaceholderPage(),
    ContactsPlaceholderPage(),
    MinePage(),
  ];

  Future<void> _showPasswordPrompt() async {
    if (_isShowingPasswordPrompt) {
      return;
    }

    final repository = context.read<AuthRepository>();
    final sessionCubit = context.read<AppSessionCubit>();
    _isShowingPasswordPrompt = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordSetupPromptDialog(
        repository: repository,
        appSessionCubit: sessionCubit,
      ),
    );
    _isShowingPasswordPrompt = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppSessionCubit, AppSessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.shouldPromptPasswordSetup !=
              current.shouldPromptPasswordSetup,
      listener: (context, state) async {
        if (state.status == AuthStatus.unauthenticated) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
          return;
        }

        if (state.shouldPromptPasswordSetup) {
          await _showPasswordPrompt();
        }
      },
      child: Scaffold(
        body: SafeArea(child: _pages[_currentIndex]),
        bottomNavigationBar: HomeNavigationBar(
          currentIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
