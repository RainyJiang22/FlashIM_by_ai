import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_friend/src/view/new_friends_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows pending actions and keeps sent and handled history', (
    tester,
  ) async {
    final cubit = FriendCubit(repository: _HistoryRepository());
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FriendCubit>.value(
          value: cubit,
          child: const NewFriendsPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('小雨'), findsOneWidget);
    expect(find.text('接受'), findsOneWidget);
    expect(find.text('拒绝'), findsOneWidget);
    expect(find.text('阿青'), findsNWidgets(2));
    expect(find.text('等待验证'), findsOneWidget);
    expect(find.text('已添加'), findsOneWidget);
    expect(cubit.state.pendingRequestCount, 1);

    await cubit.close();
  });
}

class _HistoryRepository implements FriendRepository {
  static const receivedUser = FriendUser(
    accountId: 2,
    nickname: '小雨',
    avatar: '',
    signature: '',
    relationStatus: 'pending_received',
  );
  static const sentUser = FriendUser(
    accountId: 3,
    nickname: '阿青',
    avatar: '',
    signature: '',
    relationStatus: 'pending_sent',
  );

  @override
  Future<List<FriendUser>> getFriends() async => const [];

  @override
  Future<List<FriendRequest>> getReceivedRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) async => [
    FriendRequest(
      id: 'received-1',
      fromUser: receivedUser,
      message: '我是小雨',
      status: 'pending',
      createdAt: DateTime.utc(2026, 7, 29, 8),
    ),
  ];

  @override
  Future<List<FriendRequest>> getSentRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) async => [
    FriendRequest(
      id: 'sent-1',
      fromUser: sentUser,
      message: '我是阿雨',
      status: 'pending',
      createdAt: DateTime.utc(2026, 7, 29, 7),
      direction: FriendRequestDirection.sent,
    ),
    FriendRequest(
      id: 'sent-2',
      fromUser: sentUser,
      message: '你好',
      status: 'accepted',
      createdAt: DateTime.utc(2026, 7, 28),
      direction: FriendRequestDirection.sent,
    ),
  ];

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
