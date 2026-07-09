import 'dart:async';

import 'package:flash_auth/flash_auth.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flash_starter/flash_starter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/app/app_router.dart';
import 'package:flash_im/app/session_app_starter_controller.dart';

void main() {
  testWidgets('startup page routes to login page', (tester) async {
    final authRepository = _FakeAuthRepository();
    final sessionRepository = _FakeSessionRepository();
    final cubit = SessionCubit(repository: sessionRepository);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: authRepository),
          RepositoryProvider<ConversationRepository>.value(
            value: _FakeConversationRepository(),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: onGenerateAppRoute,
            home: _buildStarterPage(cubit),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('startup page routes to home shell', (tester) async {
    final authRepository = _FakeAuthRepository();
    final sessionRepository = _FakeSessionRepository(
      cachedSession: const CachedAuthSession(
        token: 'jwt-token',
        accountId: 10001,
      ),
    );
    final cubit = SessionCubit(repository: sessionRepository);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: authRepository),
          RepositoryProvider<ConversationRepository>.value(
            value: _FakeConversationRepository(),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: onGenerateAppRoute,
            home: _buildStarterPage(cubit),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('消息'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('startup page shows retry on restore failure', (tester) async {
    final authRepository = _FakeAuthRepository();
    final sessionRepository = _ThrowingThenSuccessSessionRepository();
    final cubit = SessionCubit(repository: sessionRepository);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: authRepository),
          RepositoryProvider<ConversationRepository>.value(
            value: _FakeConversationRepository(),
          ),
          RepositoryProvider<WsClient>.value(value: _FakeWsClient()),
        ],
        child: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: onGenerateAppRoute,
            home: _buildStarterPage(cubit),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('启动失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    await cubit.close();
  });
}

AppStarterPage _buildStarterPage(SessionCubit sessionCubit) {
  return AppStarterPage(
    options: AppStarterOptions(
      controller: SessionAppStarterController(sessionCubit),
      routes: const AppStarterRoutes(
        loginRouteName: AppRoutes.login,
        homeRouteName: AppRoutes.home,
      ),
      branding: const AppStarterBranding(
        logo: SizedBox(width: 132, height: 132),
        title: 'Flash IM',
        idleSubtitle: '轻量即时通讯',
        loadingSubtitle: '正在恢复登录状态...',
      ),
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    return const AppSession(
      token: 'jwt-token',
      accountId: 10001,
      passwordSetupRequired: false,
    );
  }

  @override
  Future<AppSession> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    return const AppSession(
      token: 'jwt-token',
      accountId: 10001,
      passwordSetupRequired: false,
    );
  }

  @override
  Future<String> sendSmsCode(String phone) async => '654321';
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({this.cachedSession});

  final CachedAuthSession? cachedSession;

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
      avatar: 'identicon:startup-seed',
      phone: '13800138000',
      signature: '',
      hasPassword: true,
    );
  }

  @override
  Future<void> persistSession(AppSession session) async {}

  @override
  Future<CachedAuthSession?> readCachedSession() async => cachedSession;

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

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<Conversation> getById(String id) async {
    return Conversation(
      id: id,
      type: 0,
      peerUserId: '10002',
      peerNickname: '橘橙',
      unreadCount: 0,
      createdAt: DateTime(2026, 3, 29),
      lastMessageAt: DateTime(2026, 3, 29, 9, 12),
      lastMessagePreview: '今天的接口联调先看会话列表。',
    );
  }

  @override
  Future<List<Conversation>> getList({int limit = 20, int offset = 0}) async {
    if (offset > 0) {
      return const <Conversation>[];
    }
    return [
      Conversation(
        id: 'conversation-1',
        type: 0,
        peerUserId: '10002',
        peerNickname: '橘橙',
        unreadCount: 0,
        createdAt: DateTime(2026, 3, 29),
        lastMessageAt: DateTime(2026, 3, 29, 9, 12),
        lastMessagePreview: '今天的接口联调先看会话列表。',
      ),
    ];
  }

  @override
  Future<void> markRead(String id) async {}
}

class _FakeWsClient extends WsClient {
  _FakeWsClient()
    : super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
        tokenProvider: () => null,
      );

  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();
  WsConnectionState _state = WsConnectionState.disconnected;

  @override
  WsConnectionState get state => _state;

  @override
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  @override
  Future<void> connect() async {
    _state = WsConnectionState.authenticated;
    _stateController.add(_state);
  }

  @override
  Future<void> disconnect() async {
    _state = WsConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}

class _ThrowingThenSuccessSessionRepository extends _FakeSessionRepository {
  bool _didThrow = false;

  @override
  Future<CachedAuthSession?> readCachedSession() async {
    if (!_didThrow) {
      _didThrow = true;
      throw const FormatException('corrupted cache');
    }
    return null;
  }
}
