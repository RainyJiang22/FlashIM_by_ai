import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows implemented contact entries without unsupported shells', (
    tester,
  ) async {
    final cubit = FriendCubit(repository: _ContactsRepository());
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<FriendCubit>.value(
            value: cubit,
            child: ContactsPage(onMessageFriend: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('通讯录'), findsOneWidget);
    expect(find.text('新的朋友'), findsOneWidget);
    expect(find.text('阿青'), findsOneWidget);
    expect(find.text('扫一扫'), findsNothing);
    expect(find.text('群聊'), findsNothing);
    expect(find.text('公众号'), findsNothing);

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
