import 'package:flutter/material.dart';

import '../../../core/auth/auth_cache_store.dart';
import '../../../core/config/local_config_store.dart';
import '../data/startup_coordinator_impl.dart';
import '../domain/launch_destination.dart';
import '../domain/startup_stage.dart';
import 'home_placeholder_page.dart';
import 'login_placeholder_page.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key, StartupCoordinator? coordinator})
    : _coordinator = coordinator;

  final StartupCoordinator? _coordinator;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  late final StartupCoordinator _coordinator;
  StartupStage _stage = StartupStage.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _coordinator =
        widget._coordinator ??
        const DefaultStartupCoordinator(
          configStore: DefaultLocalConfigStore(),
          authCacheStore: SharedPreferencesAuthCacheStore(),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _stage = StartupStage.loading;
      _errorMessage = null;
    });

    try {
      final snapshot = await _coordinator.bootstrap();
      if (!mounted) {
        return;
      }


      setState(() {
        _stage = StartupStage.ready;
      });

      Future.delayed(Duration(milliseconds: 3000),() {
        _goToDestination(snapshot.destination);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _stage = StartupStage.failed;
        _errorMessage = '启动失败，请重试';
      });
    }
  }

  void _goToDestination(LaunchDestination destination) {
    final page = switch (destination) {
      LaunchDestination.login => const LoginPlaceholderPage(),
      LaunchDestination.home => const HomePlaceholderPage(),
    };

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const appBackgroundColor = Color(0xFFF6F7F9);

    return Scaffold(
      backgroundColor: appBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/branding/flash_im_logo.png', width: 132),
                const SizedBox(height: 20),
                Text(
                  'Flash IM',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF1C4EFF),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _stage == StartupStage.failed ? '启动失败' : '正在启动',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_stage == StartupStage.failed) ...[
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage ?? '启动失败，请重试',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFB42318),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _bootstrap, child: const Text('重试')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
