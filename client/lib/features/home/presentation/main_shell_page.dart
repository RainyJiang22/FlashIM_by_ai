import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/app_router.dart';
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

    final sessionCubit = context.read<SessionCubit>();
    _isShowingPasswordPrompt = true;
    final shouldSetNow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordSetupPromptDialog(
        onSkip: () {
          sessionCubit.markPasswordPromptHandled();
          Navigator.of(context).pop(false);
        },
        onSetNow: () {
          sessionCubit.markPasswordPromptHandled();
          Navigator.of(context).pop(true);
        },
      ),
    );
    _isShowingPasswordPrompt = false;
    if (shouldSetNow == true && mounted) {
      await Navigator.of(context).pushNamed(AppRoutes.setPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionCubit, SessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.shouldPromptPasswordSetup !=
              current.shouldPromptPasswordSetup,
      listener: (context, state) async {
        if (state.status == SessionStatus.unauthenticated) {
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
