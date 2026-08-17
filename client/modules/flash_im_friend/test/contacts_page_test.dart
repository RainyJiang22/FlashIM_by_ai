import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows implemented contact entries without unsupported shells', (
    tester,
  ) async {
    final cubit = FriendCubit(repository: _ContactsRepository());
    FriendUser? messagedUser;
    var openedGroups = false;
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<FriendCubit>.value(
            value: cubit,
            child: ContactsPage(
              onMessageFriend: (user) => messagedUser = user,
              onOpenGroups: () => openedGroups = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('通讯录'), findsOneWidget);
    expect(find.text('新的朋友'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('阿青'), findsOneWidget);
    expect(find.text('扫一扫'), findsNothing);
    expect(find.text('群聊'), findsOneWidget);
    expect(find.text('公众号'), findsNothing);

    final screenWidth = tester.getSize(find.byType(Scaffold).first).width;
    final titleCenter = tester.getCenter(find.text('通讯录'));
    final searchCenter = tester.getCenter(find.byTooltip('搜索好友'));
    final addCenter = tester.getCenter(find.byTooltip('添加朋友'));
    expect(titleCenter.dx, closeTo(screenWidth / 2, 0.5));
    expect(searchCenter.dx, greaterThan(screenWidth - 100));
    expect(addCenter.dx, greaterThan(searchCenter.dx));

    await tester.tap(find.text('群聊'));
    expect(openedGroups, isTrue);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('阿青'));
    await tester.pumpAndSettle();

    expect(find.text('闪讯号：flash_1'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('个性签名'), findsOneWidget);
    expect(find.text('今天也要保持联系'), findsWidgets);
    expect(find.text('发消息'), findsOneWidget);
    expect(find.text('朋友圈'), findsNothing);
    expect(find.text('朋友权限'), findsNothing);
    expect(find.text('音视频通话'), findsNothing);

    await tester.tap(find.text('发消息'));
    expect(messagedUser?.accountId, 1);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('删除好友'), findsOneWidget);

    await cubit.close();
  });
}

class _ContactsRepository implements FriendRepository {
  @override
  Future<List<FriendUser>> getFriends() async => const [
    FriendUser(
      accountId: 1,
      nickname: '阿青',
      avatar: '',
      signature: '今天也要保持联系',
      flashId: 'flash_1',
      relationStatus: 'friend',
    ),
  ];

  @override
  Future<List<FriendRequest>> getReceivedRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) async => [
    FriendRequest(
      id: 'request-1',
      fromUser: const FriendUser(
        accountId: 2,
        nickname: '白露',
        avatar: '',
        signature: '',
      ),
      message: '你好',
      status: 'pending',
      createdAt: DateTime(2026, 8, 16),
    ),
  ];

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
