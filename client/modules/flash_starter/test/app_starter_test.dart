import 'dart:async';

import 'package:flash_starter/flash_starter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports starter models', () async {
    const routes = AppStarterRoutes(
      loginRouteName: '/login',
      homeRouteName: '/home',
    );
    final controller = _FakeAppStarterController();
    final options = AppStarterOptions(
      controller: controller,
      routes: routes,
      branding: const AppStarterBranding(
        logo: SizedBox(width: 100, height: 100),
        title: 'Flash IM',
        idleSubtitle: '轻量即时通讯',
        loadingSubtitle: '正在恢复登录状态...',
      ),
    );

    expect(AppStarterStage.values, hasLength(4));
    expect(options.routes.homeRouteName, '/home');
    await controller.close();
  });

  testWidgets('routes to login when starter restore reports unauthenticated', (
    tester,
  ) async {
    final controller = _FakeAppStarterController(
      onRestore: () =>
          const AppStarterState(status: AppStarterStatus.unauthenticated),
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/login': (_) => const Scaffold(body: Text('login')),
          '/home': (_) => const Scaffold(body: Text('home')),
        },
        home: AppStarterPage(
          options: AppStarterOptions(
            controller: controller,
            routes: const AppStarterRoutes(
              loginRouteName: '/login',
              homeRouteName: '/home',
            ),
            branding: const AppStarterBranding(
              logo: SizedBox(width: 100, height: 100),
              title: 'Flash IM',
              idleSubtitle: '轻量即时通讯',
              loadingSubtitle: '正在恢复登录状态...',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    await controller.close();
  });

  testWidgets('shows retry when starter restore fails', (tester) async {
    final controller = _FakeAppStarterController(
      onRestore: () => const AppStarterState(
        status: AppStarterStatus.failure,
        errorMessage: '启动失败，请重试',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppStarterPage(
          options: AppStarterOptions(
            controller: controller,
            routes: const AppStarterRoutes(
              loginRouteName: '/login',
              homeRouteName: '/home',
            ),
            branding: const AppStarterBranding(
              logo: SizedBox(width: 100, height: 100),
              title: 'Flash IM',
              idleSubtitle: '轻量即时通讯',
              loadingSubtitle: '正在恢复登录状态...',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('启动失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await controller.close();
  });
}

class _FakeAppStarterController implements AppStarterController {
  _FakeAppStarterController({AppStarterState Function()? onRestore})
    : _onRestore = onRestore;

  final AppStarterState Function()? _onRestore;
  final StreamController<AppStarterState> _controller =
      StreamController<AppStarterState>.broadcast();
  AppStarterState _state = const AppStarterState.initial();

  @override
  AppStarterState get state => _state;

  @override
  Stream<AppStarterState> get stream => _controller.stream;

  @override
  Future<void> restore() async {
    emit(const AppStarterState(status: AppStarterStatus.restoring));
    emit(
      _onRestore?.call() ??
          const AppStarterState(status: AppStarterStatus.unauthenticated),
    );
  }

  void emit(AppStarterState state) {
    _state = state;
    _controller.add(state);
  }

  Future<void> close() {
    return _controller.close();
  }
}
