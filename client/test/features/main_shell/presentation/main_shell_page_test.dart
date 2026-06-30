import 'dart:async';

import 'package:flash_auth/flash_auth.dart';
import 'package:flash_im/app/app_router.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/features/home/presentation/main_shell_page.dart';

void main() {
  testWidgets('main shell shows password setup prompt and switches tabs', (
    tester,
  ) async {
    final repository = _FakeSessionRepository();
    final cubit = SessionCubit(repository: repository);
    final wsClient = _FakeWsClient();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [RepositoryProvider<WsClient>.value(value: wsClient)],
        child: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            routes: {AppRoutes.login: (_) => const Scaffold(body: Text('登录页'))},
            home: const MainShellPage(),
          ),
        ),
      ),
    );

    await cubit.completeLogin(
      const AppSession(
        token: 'jwt-token',
        accountId: 10001,
        passwordSetupRequired: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(wsClient.connectCount, 1);
    expect(find.text('设置登录密码'), findsOneWidget);
    await tester.tap(find.text('稍后设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置登录密码'), findsNothing);
    expect(find.text('Rainy'), findsOneWidget);
    expect(find.text('消息同步状态'), findsOneWidget);
    expect(find.text('已连接'), findsOneWidget);

    await tester.tap(find.text('通讯录'));
    await tester.pumpAndSettle();
    expect(find.text('通讯录页暂未开放'), findsOneWidget);

    await cubit.logout();
    await tester.pumpAndSettle();
    expect(wsClient.disconnectCount, 1);
    expect(find.text('登录页'), findsOneWidget);

    await cubit.close();
  });
}

class _FakeWsClient extends WsClient {
  _FakeWsClient()
    : super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
        tokenProvider: () => null,
      );

  final _stateController = StreamController<WsConnectionState>.broadcast();
  WsConnectionState _state = WsConnectionState.disconnected;
  int connectCount = 0;
  int disconnectCount = 0;

  @override
  WsConnectionState get state => _state;

  @override
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  @override
  Future<void> connect() async {
    connectCount += 1;
    _state = WsConnectionState.authenticated;
    _stateController.add(_state);
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    _state = WsConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}

class _FakeSessionRepository implements SessionRepository {
  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<User> fetchProfile() async {
    return const User(
      userId: 10001,
      nickname: 'Rainy',
      avatar: 'identicon:seed-main-shell',
      phone: '13800138000',
      signature: '',
      hasPassword: false,
    );
  }

  @override
  Future<void> persistSession(AppSession session) async {}

  @override
  Future<CachedAuthSession?> readCachedSession() async => null;

  @override
  Future<void> setPassword({required String newPassword}) async {}

  @override
  Future<User> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    return await fetchProfile();
  }
}
