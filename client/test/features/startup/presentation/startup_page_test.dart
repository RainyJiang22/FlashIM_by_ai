import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/core/config/app_config.dart';
import 'package:flash_im/features/startup/data/startup_coordinator_impl.dart';
import 'package:flash_im/features/startup/domain/app_bootstrap_snapshot.dart';
import 'package:flash_im/features/startup/domain/launch_destination.dart';
import 'package:flash_im/features/startup/presentation/startup_page.dart';

void main() {
  testWidgets('startup page routes to login placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartupPage(coordinator: _FakeStartupCoordinator.login()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('登录页占位'), findsOneWidget);
  });

  testWidgets('startup page routes to home placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartupPage(coordinator: _FakeStartupCoordinator.home()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('主页面占位'), findsOneWidget);
  });

  testWidgets('startup page shows retry on bootstrap failure', (tester) async {
    final coordinator = _FailingThenSuccessCoordinator();
    await tester.pumpWidget(
      MaterialApp(home: StartupPage(coordinator: coordinator)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('启动失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('登录页占位'), findsOneWidget);
  });
}

class _FakeStartupCoordinator implements StartupCoordinator {
  const _FakeStartupCoordinator._(this.destination);

  factory _FakeStartupCoordinator.home() =>
      const _FakeStartupCoordinator._(LaunchDestination.home);

  factory _FakeStartupCoordinator.login() =>
      const _FakeStartupCoordinator._(LaunchDestination.login);

  final LaunchDestination destination;

  @override
  Future<AppBootstrapSnapshot> bootstrap() async {
    return AppBootstrapSnapshot(
      destination: destination,
      hasAuthSession: destination == LaunchDestination.home,
      config: const LocalAppConfig(
        appName: 'Flash IM',
        apiBaseUrl: 'http://127.0.0.1:9600',
        enableDebugTools: false,
      ),
    );
  }
}

class _FailingThenSuccessCoordinator implements StartupCoordinator {
  bool _didFail = false;

  @override
  Future<AppBootstrapSnapshot> bootstrap() async {
    if (!_didFail) {
      _didFail = true;
      throw Exception('bootstrap failed');
    }

    return const AppBootstrapSnapshot(
      destination: LaunchDestination.login,
      hasAuthSession: false,
      config: LocalAppConfig(
        appName: 'Flash IM',
        apiBaseUrl: 'http://127.0.0.1:9600',
        enableDebugTools: false,
      ),
    );
  }
}
