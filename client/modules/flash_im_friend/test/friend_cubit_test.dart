import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load exposes friends and pending request count', () async {
    final repository = _FakeFriendRepository();
    final cubit = FriendCubit(repository: repository);

    await cubit.load();

    expect(cubit.state.friends.single.displayName, '阿青');
    expect(cubit.state.pendingRequestCount, 1);
    await cubit.close();
  });

  test(
    'accept keeps request history and moves user into friend list',
    () async {
      final repository = _FakeFriendRepository();
      final cubit = FriendCubit(repository: repository);
      await cubit.load();
      final request = cubit.state.receivedRequests.single;

      final result = await cubit.acceptRequest(request);

      expect(result?.conversationId, 'conversation-1');
      expect(cubit.state.receivedRequests.single.status, 'accepted');
      expect(cubit.state.pendingRequestCount, 0);
      expect(
        cubit.state.friends.any((user) => user.accountId == 2 && user.isFriend),
        isTrue,
      );
      await cubit.close();
    },
  );
}

class _FakeFriendRepository implements FriendRepository {
  static const friend = FriendUser(
    accountId: 1,
    nickname: '阿青',
    avatar: '',
    signature: '',
    relationStatus: 'friend',
  );
  static const requester = FriendUser(
    accountId: 2,
    nickname: '小雨',
    avatar: '',
    signature: '',
    relationStatus: 'pending_received',
  );

  @override
  Future<List<FriendUser>> getFriends() async => const [friend];

  @override
  Future<List<FriendRequest>> getReceivedRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) async => [
    FriendRequest(
      id: 'request-1',
      fromUser: requester,
      message: '你好',
      status: 'pending',
      createdAt: DateTime.utc(2026, 7, 29),
    ),
  ];

  @override
  Future<List<FriendRequest>> getSentRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) async => const [];

  @override
  Future<FriendAcceptResult> acceptRequest(String requestId) async {
    return const FriendAcceptResult(
      requestId: 'request-1',
      friend: FriendUser(
        accountId: 2,
        nickname: '小雨',
        avatar: '',
        signature: '',
        relationStatus: 'friend',
      ),
      conversationId: 'conversation-1',
    );
  }

  @override
  Future<FriendUser> getUser(int accountId) async => requester;

  @override
  Future<void> rejectRequest(String requestId) async {}

  @override
  Future<void> removeFriend(int accountId) async {}

  @override
  Future<List<FriendUser>> searchUsers(String query, {int limit = 30}) async =>
      const [requester];

  @override
  Future<void> sendRequest({
    required int toUserId,
    required String message,
  }) async {}
}
