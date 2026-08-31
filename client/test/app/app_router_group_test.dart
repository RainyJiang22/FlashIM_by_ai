import 'package:flash_im/app/app_router.dart';
import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart' hide FriendUser;
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group route table accepts valid and rejects invalid arguments', () {
    expect(
      onGenerateAppRoute(const RouteSettings(name: AppRoutes.createGroup)),
      isA<MaterialPageRoute<Conversation>>(),
    );
    expect(
      onGenerateAppRoute(const RouteSettings(name: AppRoutes.myGroups)),
      isA<MaterialPageRoute<Conversation>>(),
    );
    expect(
      onGenerateAppRoute(
        const RouteSettings(name: AppRoutes.privateChatDetails),
      ),
      isA<MaterialPageRoute<void>>(),
    );
    expect(
      onGenerateAppRoute(const RouteSettings(name: AppRoutes.chat)),
      isA<MaterialPageRoute<void>>(),
    );
    expect(
      onGenerateAppRoute(const RouteSettings(name: AppRoutes.groupDetails)),
      isA<MaterialPageRoute<void>>(),
    );
    expect(onGenerateAppRoute(const RouteSettings(name: '/missing')), isNull);
  });

  testWidgets('builds create, group list and private detail routes', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final context = tester.element(find.text('home'));

    Navigator.of(context).pushNamed(
      AppRoutes.createGroup,
      arguments: const CreateGroupRouteArguments(),
    );
    await tester.pumpAndSettle();
    expect(find.text('发起群聊'), findsOneWidget);
    Navigator.of(tester.element(find.text('发起群聊'))).pop();
    await tester.pumpAndSettle();

    Navigator.of(context).pushNamed(AppRoutes.myGroups);
    await tester.pumpAndSettle();
    expect(find.text('我的群聊'), findsOneWidget);
    Navigator.of(tester.element(find.text('我的群聊'))).pop();
    await tester.pumpAndSettle();

    Navigator.of(context).pushNamed(
      AppRoutes.privateChatDetails,
      arguments: const PrivateChatDetailsRouteArguments(
        friend: FriendUser(
          accountId: 2,
          nickname: '阿青',
          avatar: 'identicon:2',
          signature: '',
        ),
        currentUserId: '1',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('聊天详情'), findsOneWidget);
  });

  testWidgets('private chat invite creates group and replaces chat route', (
    tester,
  ) async {
    final conversations = _ConversationRepository();
    await tester.pumpWidget(_app(conversations: conversations));
    final context = tester.element(find.text('home'));

    Navigator.of(context).pushNamed(
      AppRoutes.chat,
      arguments: ChatRouteArguments(
        conversation: Conversation(
          id: 'private-1',
          type: 0,
          peerUserId: '2',
          peerNickname: '阿青',
          peerAvatar: 'identicon:2',
          unreadCount: 0,
          createdAt: DateTime(2026, 8, 16),
        ),
        currentUserId: '1',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat-details-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-more-to-group')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('select-friend-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create-group-submit')));
    await tester.pumpAndSettle();

    expect(find.text('新群聊'), findsOneWidget);
    expect(conversations.createdMemberIds, [2, 3]);
  });

  testWidgets('group chat opens details and updates title on return', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final context = tester.element(find.text('home'));
    Navigator.of(context).pushNamed(
      AppRoutes.chat,
      arguments: ChatRouteArguments(
        conversation: Conversation(
          id: 'group-1',
          type: 1,
          name: '旧群名',
          unreadCount: 0,
          createdAt: DateTime(2026, 8, 17),
        ),
        currentUserId: '1',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat-details-action')));
    await tester.pumpAndSettle();
    expect(find.text('聊天信息'), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-name-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-name-input')), '新群名');
    await tester.tap(find.byKey(const Key('group-name-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('新群名'), findsOneWidget);
  });
}

Widget _app({_ConversationRepository? conversations}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FriendRepository>.value(value: _FriendRepository()),
      RepositoryProvider<ConversationRepository>.value(
        value: conversations ?? _ConversationRepository(),
      ),
      RepositoryProvider<MessageRepository>.value(
        value: const _MessageRepository(),
      ),
      RepositoryProvider<GroupRepository>.value(value: _GroupRepository()),
      RepositoryProvider<WsClient>.value(value: _WsClient()),
    ],
    child: MaterialApp(
      onGenerateRoute: onGenerateAppRoute,
      home: const Scaffold(body: Text('home')),
    ),
  );
}

class _GroupRepository implements GroupRepository {
  var detail = GroupDetail(
    conversationId: 'group-1',
    name: '旧群名',
    avatar: 'grid:identicon:1',
    ownerId: 1,
    joinApprovalRequired: false,
    currentUserRole: 'owner',
    memberCount: 1,
    members: [
      GroupMember(
        accountId: 1,
        nickname: '群主',
        avatar: 'identicon:1',
        isOwner: true,
        joinedAt: DateTime(2026, 8, 17),
      ),
    ],
  );

  @override
  Future<Conversation> acceptInvitation(String invitationId) =>
      throw UnimplementedError();
  @override
  Future<GroupDetail> addMembers(String groupId, List<int> memberIds) async =>
      detail;
  @override
  Future<void> dissolveGroup(String groupId) async {}
  @override
  Future<GroupDetail> getDetail(String groupId) async => detail;
  @override
  Future<GroupJoinRequestList> getJoinRequests() async =>
      GroupJoinRequestList(pendingCount: 0, requests: []);
  @override
  Future<GroupJoinRequest> handleJoinRequest(
    String groupId,
    String requestId, {
    required bool approved,
  }) => throw UnimplementedError();
  @override
  Future<void> inviteMembers(String groupId, List<int> inviteeIds) async {}
  @override
  Future<JoinGroupResult> joinGroup(String groupId, {String? message}) =>
      throw UnimplementedError();
  @override
  Future<GroupDetail> removeMember(String groupId, int memberId) async =>
      detail;
  @override
  Future<List<GroupSearchItem>> searchGroups(String keyword) async => const [];
  @override
  Future<GroupDetail> updateName(String groupId, String name) async {
    detail = GroupDetail(
      conversationId: detail.conversationId,
      name: name,
      avatar: detail.avatar,
      ownerId: detail.ownerId,
      joinApprovalRequired: detail.joinApprovalRequired,
      currentUserRole: detail.currentUserRole,
      memberCount: detail.memberCount,
      members: detail.members,
    );
    return detail;
  }

  @override
  Future<GroupDetail> updateSettings(
    String groupId, {
    required bool joinApprovalRequired,
  }) async => detail;
}

class _ConversationRepository implements ConversationRepository {
  List<int>? createdMemberIds;

  @override
  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    createdMemberIds = memberIds;
    return Conversation(
      id: 'group-1',
      type: 1,
      name: '新群聊',
      unreadCount: 0,
      createdAt: DateTime(2026, 8, 16),
    );
  }

  @override
  Future<Conversation> getById(String id) => throw UnimplementedError();

  @override
  Future<List<Conversation>> getList({
    int limit = 20,
    int offset = 0,
    int? type,
  }) async => const [];

  @override
  Future<void> markRead(String id) async {}
}

class _FriendRepository implements FriendRepository {
  @override
  Future<List<FriendUser>> getFriends() async => const [
    FriendUser(
      accountId: 2,
      nickname: '阿青',
      avatar: 'identicon:2',
      signature: '',
      relationStatus: 'friend',
    ),
    FriendUser(
      accountId: 3,
      nickname: '白露',
      avatar: 'identicon:3',
      signature: '',
      relationStatus: 'friend',
    ),
  ];

  @override
  Future<FriendAcceptResult> acceptRequest(String requestId) =>
      throw UnimplementedError();
  @override
  Future<FriendUser> getUser(int accountId) => throw UnimplementedError();
  @override
  Future<List<FriendRequest>> getReceivedRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) => throw UnimplementedError();
  @override
  Future<List<FriendRequest>> getSentRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) => throw UnimplementedError();
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

class _MessageRepository implements MessageRepository {
  const _MessageRepository();

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  }) async => const [];
  @override
  Future<String> downloadFile(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) => throw UnimplementedError();
  @override
  Future<FileUploadResult> uploadFile(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) => throw UnimplementedError();
  @override
  Future<ImageUploadResult> uploadImage(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) => throw UnimplementedError();
  @override
  Future<VideoUploadResult> uploadVideo(
    String videoPath,
    String thumbPath,
    int durationMs, {
    int? width,
    int? height,
    void Function(int sent, int total)? onProgress,
  }) => throw UnimplementedError();
}

class _WsClient extends WsClient {
  _WsClient()
    : super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
        tokenProvider: () => null,
      );
}
