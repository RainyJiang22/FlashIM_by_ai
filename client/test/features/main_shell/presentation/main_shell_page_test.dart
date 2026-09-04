import 'dart:async';
import 'dart:convert';

import 'package:flash_auth/flash_auth.dart';
import 'package:flash_im/app/app_router.dart';
import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart' hide FriendUser;
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flash_im_search/flash_im_search.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/features/home/presentation/main_shell_page.dart';

void main() {
  testWidgets('only mentioned account receives the mention alert dialog', (
    tester,
  ) async {
    final cubit = SessionCubit(
      repository: _FakeSessionRepository(hasPassword: true),
    );
    final wsClient = _FakeWsClient();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WsClient>.value(value: wsClient),
          RepositoryProvider<ConversationRepository>.value(
            value: _FakeConversationRepository(),
          ),
          RepositoryProvider<FriendRepository>.value(
            value: _FakeFriendRepository(),
          ),
          RepositoryProvider<GroupRepository>.value(
            value: _FakeGroupRepository(),
          ),
          RepositoryProvider<SearchRepository>.value(
            value: _FakeSearchRepository(),
          ),
        ],
        child: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: const MaterialApp(home: MainShellPage()),
        ),
      ),
    );
    await cubit.completeLogin(
      const AppSession(
        token: 'jwt-token',
        accountId: 10001,
        passwordSetupRequired: false,
      ),
    );
    await tester.pumpAndSettle();

    wsClient.emitMessage(
      ChatMessage(
        id: 'mention-1',
        conversationId: 'group-1',
        senderId: 2,
        seq: 1,
        content: '@Rainy 请查看',
        extra: jsonEncode({
          'mention_all': false,
          'mentions': [
            {'user_id': '10001', 'nickname': 'Rainy'},
          ],
        }),
        senderName: '阿青',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mention-alert-dialog')), findsOneWidget);
    expect(find.text('有人@你'), findsOneWidget);
    expect(find.text('阿青：@Rainy 请查看'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mention-alert-confirm')));
    await tester.pumpAndSettle();

    wsClient.emitMessage(
      ChatMessage(
        id: 'mention-2',
        conversationId: 'group-1',
        senderId: 2,
        seq: 2,
        content: '@别人 请查看',
        extra: jsonEncode({
          'mention_all': false,
          'mentions': [
            {'user_id': '10002', 'nickname': '别人'},
          ],
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mention-alert-dialog')), findsNothing);

    wsClient.emitMessage(
      ChatMessage(
        id: 'mention-3',
        conversationId: 'group-1',
        senderId: 3,
        seq: 3,
        content: '@所有人 开会',
        extra: jsonEncode({'mention_all': true, 'mentions': []}),
        senderName: '管理员',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mention-alert-dialog')), findsOneWidget);
    expect(find.text('@所有人提醒'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mention-alert-confirm')));
    await tester.pumpAndSettle();

    await cubit.close();
    await wsClient.dispose();
  });

  testWidgets('main shell shows password setup prompt and switches tabs', (
    tester,
  ) async {
    final sessionRepository = _FakeSessionRepository();
    final conversationRepository = _FakeConversationRepository();
    final cubit = SessionCubit(repository: sessionRepository);
    final wsClient = _FakeWsClient();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WsClient>.value(value: wsClient),
          RepositoryProvider<ConversationRepository>.value(
            value: conversationRepository,
          ),
          RepositoryProvider<FriendRepository>.value(
            value: _FakeFriendRepository(),
          ),
          RepositoryProvider<GroupRepository>.value(
            value: _FakeGroupRepository(),
          ),
          RepositoryProvider<SearchRepository>.value(
            value: _FakeSearchRepository(),
          ),
        ],
        child: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: MaterialApp(
            routes: {
              AppRoutes.chat: (_) => const Scaffold(body: Text('聊天页')),
              AppRoutes.login: (_) => const Scaffold(body: Text('登录页')),
              AppRoutes.createGroup: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    Conversation(
                      id: 'group-1',
                      type: 1,
                      name: '测试群聊',
                      unreadCount: 0,
                      createdAt: DateTime(2026, 8, 16),
                    ),
                  ),
                  child: const Text('建群完成'),
                ),
              ),
              AppRoutes.myGroups: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    Conversation(
                      id: 'group-2',
                      type: 1,
                      name: '已有群聊',
                      unreadCount: 0,
                      createdAt: DateTime(2026, 8, 16),
                    ),
                  ),
                  child: const Text('选择已有群'),
                ),
              ),
            },
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
    expect(find.text('已连接'), findsOneWidget);
    expect(find.text('橘橙'), findsOneWidget);
    expect(find.text('今天的接口联调先看会话列表。'), findsOneWidget);
    expect(find.text('消息页暂未开放'), findsNothing);
    expect(find.text('3'), findsWidgets);

    await tester.tap(find.byKey(const Key('messages-comprehensive-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comprehensive-search-field')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('comprehensive-search-field'))),
    ).pop();
    await tester.pumpAndSettle();

    final triggerBottom = tester.getBottomLeft(
      find.byKey(const Key('messages-create-group')),
    );
    await tester.tap(find.byKey(const Key('messages-create-group')));
    await tester.pumpAndSettle();
    expect(find.text('发起群聊'), findsOneWidget);
    expect(find.text('添加群/联系人'), findsOneWidget);
    final actionTop = tester.getTopLeft(find.text('发起群聊'));
    expect(actionTop.dy, greaterThan(triggerBottom.dy));
    await tester.tap(find.text('添加群/联系人'));
    await tester.pumpAndSettle();
    expect(find.text('加好友/群'), findsOneWidget);
    await tester.tap(find.text('搜索账号 / 手机号'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('返回'), findsOneWidget);
    Navigator.of(tester.element(find.byTooltip('返回'))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('加好友/群'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('messages-create-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发起群聊'));
    await tester.pumpAndSettle();
    expect(find.text('建群完成'), findsOneWidget);
    await tester.tap(find.text('建群完成'));
    await tester.pumpAndSettle();
    expect(find.text('聊天页'), findsOneWidget);
    Navigator.of(tester.element(find.text('聊天页'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('橘橙'));
    await tester.pumpAndSettle();
    expect(conversationRepository.markReadIds, contains('conversation-1'));
    expect(find.text('聊天页'), findsOneWidget);

    Navigator.of(tester.element(find.text('聊天页'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);

    await tester.tap(find.text('通讯录'));
    await tester.pumpAndSettle();
    expect(find.text('新的朋友'), findsOneWidget);
    expect(find.text('小雨'), findsOneWidget);
    expect(find.text('通讯录页暂未开放'), findsNothing);

    await tester.tap(find.text('群聊'));
    await tester.pumpAndSettle();
    expect(find.text('选择已有群'), findsOneWidget);
    await tester.tap(find.text('选择已有群'));
    await tester.pumpAndSettle();
    expect(find.text('聊天页'), findsOneWidget);
    Navigator.of(tester.element(find.text('聊天页'))).pop();
    await tester.pumpAndSettle();

    await cubit.logout();
    await tester.pumpAndSettle();
    expect(wsClient.disconnectCount, 1);
    expect(find.text('登录页'), findsOneWidget);

    await cubit.close();
  });
}

class _FakeFriendRepository implements FriendRepository {
  @override
  Future<List<FriendUser>> getFriends() async => const [
    FriendUser(
      accountId: 10003,
      nickname: '小雨',
      avatar: 'identicon:10003',
      signature: '',
      relationStatus: 'friend',
    ),
  ];

  @override
  Future<List<FriendRequest>> getReceivedRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) async => const [];

  @override
  Future<List<FriendRequest>> getSentRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) async => const [];

  @override
  Future<FriendAcceptResult> acceptRequest(String requestId) =>
      throw UnimplementedError();

  @override
  Future<FriendUser> getUser(int accountId) => throw UnimplementedError();

  @override
  Future<void> rejectRequest(String requestId) => throw UnimplementedError();

  @override
  Future<void> removeFriend(int accountId) => throw UnimplementedError();

  @override
  Future<List<FriendUser>> searchUsers(String query, {int limit = 30}) =>
      throw UnimplementedError();

  @override
  Future<void> sendRequest({required int toUserId, required String message}) =>
      throw UnimplementedError();
}

class _FakeConversationRepository implements ConversationRepository {
  final markReadIds = <String>[];

  @override
  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
  }) => throw UnimplementedError();

  @override
  Future<List<Conversation>> getList({
    int limit = 20,
    int offset = 0,
    int? type,
  }) async {
    if (type == 1) {
      return const <Conversation>[];
    }
    if (offset > 0) {
      return const <Conversation>[];
    }
    return [
      Conversation(
        id: 'conversation-1',
        type: 0,
        peerUserId: '10002',
        peerNickname: '橘橙',
        unreadCount: 3,
        createdAt: DateTime(2026, 3, 29),
        lastMessageAt: DateTime(2026, 3, 29, 9, 12),
        lastMessagePreview: '今天的接口联调先看会话列表。',
      ),
    ];
  }

  @override
  Future<Conversation> getById(String id) async {
    return Conversation(
      id: id,
      type: 0,
      peerUserId: '10002',
      peerNickname: '橘橙',
      unreadCount: 3,
      createdAt: DateTime(2026, 3, 29),
      lastMessageAt: DateTime(2026, 3, 29, 9, 12),
      lastMessagePreview: '今天的接口联调先看会话列表。',
    );
  }

  @override
  Future<Conversation> getPrivateByPeerId(int peerUserId) =>
      getById('conversation-1');

  @override
  Future<void> hideFromList(String id) async {}

  @override
  Future<void> markRead(String id) async {
    markReadIds.add(id);
  }
}

class _FakeGroupRepository implements GroupRepository {
  @override
  Future<GroupJoinRequestList> getJoinRequests() async =>
      GroupJoinRequestList(pendingCount: 0, requests: []);

  @override
  Future<Conversation> acceptInvitation(String invitationId) =>
      throw UnimplementedError();

  @override
  Future<GroupDetail> addMembers(String groupId, List<int> memberIds) =>
      throw UnimplementedError();

  @override
  Future<void> dissolveGroup(String groupId) => throw UnimplementedError();

  @override
  Future<void> leaveGroup(String groupId) => throw UnimplementedError();

  @override
  Future<GroupDetail> getDetail(String groupId) => throw UnimplementedError();

  @override
  Future<GroupJoinRequest> handleJoinRequest(
    String groupId,
    String requestId, {
    required bool approved,
  }) => throw UnimplementedError();

  @override
  Future<void> inviteMembers(String groupId, List<int> inviteeIds) =>
      throw UnimplementedError();

  @override
  Future<JoinGroupResult> joinGroup(String groupId, {String? message}) =>
      throw UnimplementedError();

  @override
  Future<GroupDetail> removeMember(String groupId, int memberId) =>
      throw UnimplementedError();

  @override
  Future<GroupDetail> transferOwner(String groupId, int ownerId) =>
      throw UnimplementedError();

  @override
  Future<List<GroupSearchItem>> searchGroups(String keyword) async => const [];

  @override
  Future<GroupDetail> updateName(String groupId, String name) =>
      throw UnimplementedError();

  @override
  Future<GroupDetail> updateNickname(String groupId, String nickname) =>
      throw UnimplementedError();

  @override
  Future<GroupDetail> updateAnnouncement(String groupId, String announcement) =>
      throw UnimplementedError();

  @override
  Future<GroupDetail> updateAdmins(String groupId, List<int> memberIds) =>
      throw UnimplementedError();

  @override
  Future<GroupDetail> updateSettings(
    String groupId, {
    required bool joinApprovalRequired,
  }) => throw UnimplementedError();
}

class _FakeSearchRepository implements SearchRepository {
  @override
  Future<List<FriendUser>> searchFriends(String query) async => const [];

  @override
  Future<List<Conversation>> searchJoinedGroups(String query) async => const [];

  @override
  Future<List<MessageSearchGroup>> searchMessages(String query) async =>
      const [];

  @override
  Future<List<Message>> searchConversationMessages({
    required String conversationId,
    required String query,
  }) async => const [];
}

class _FakeWsClient extends WsClient {
  _FakeWsClient()
    : super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
        tokenProvider: () => null,
      );

  final _stateController = StreamController<WsConnectionState>.broadcast();
  final _chatMessages = StreamController<ChatMessage>.broadcast(sync: true);
  WsConnectionState _state = WsConnectionState.disconnected;
  int connectCount = 0;
  int disconnectCount = 0;

  @override
  WsConnectionState get state => _state;

  @override
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<ChatMessage> get chatMessageStream => _chatMessages.stream;

  void emitMessage(ChatMessage message) => _chatMessages.add(message);

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
    await _chatMessages.close();
    await _stateController.close();
  }
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({this.hasPassword = false});

  final bool hasPassword;

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<User> fetchProfile() async {
    return User(
      userId: 10001,
      nickname: 'Rainy',
      avatar: 'identicon:seed-main-shell',
      phone: '13800138000',
      signature: '',
      hasPassword: hasPassword,
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
