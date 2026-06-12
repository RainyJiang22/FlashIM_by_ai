// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flash_im/app/flash_im_app.dart';
import 'package:flash_im/core/config/app_config.dart';
import 'package:flash_im/features/startup/data/startup_coordinator_impl.dart';
import 'package:flash_im/features/startup/domain/app_bootstrap_snapshot.dart';
import 'package:flash_im/features/startup/domain/launch_destination.dart';

void main() {
  testWidgets('main app opens startup flow first', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const FlashImApp(startupCoordinator: _ImmediateStartupCoordinator()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('主页面占位'), findsOneWidget);
  });
}

class _ImmediateStartupCoordinator implements StartupCoordinator {
  const _ImmediateStartupCoordinator();

  @override
  Future<AppBootstrapSnapshot> bootstrap() async {
    return const AppBootstrapSnapshot(
      destination: LaunchDestination.home,
      hasAuthSession: true,
      config: LocalAppConfig(
        appName: 'Flash IM',
        apiBaseUrl: 'http://127.0.0.1:9600',
        enableDebugTools: false,
      ),
    );
  }
}
