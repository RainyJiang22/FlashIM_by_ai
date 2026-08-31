import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  test(
    'loads pending requests, deduplicates ws events and handles approval',
    () async {
      final pending = _request('request-1');
      final repository = FakeGroupRepository(
        joinRequests: GroupJoinRequestList(
          pendingCount: 1,
          requests: [pending],
        ),
      );
      final wsClient = _FakeWsClient();
      final cubit = GroupNotificationCubit(
        repository: repository,
        wsClient: wsClient,
      );

      await cubit.load();
      expect(cubit.state.pendingCount, 1);
      wsClient.add(_notification('request-1'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.requests, hasLength(1));
      expect(cubit.state.pendingCount, 1);

      wsClient.add(_notification('request-2'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.requests, hasLength(2));
      expect(cubit.state.pendingCount, 2);

      expect(await cubit.handle(pending, approved: true), isTrue);
      expect(cubit.state.pendingCount, 1);
      expect(cubit.state.requests.last.status, GroupJoinRequestStatus.approved);
      expect(repository.handleJoinRequestCalls.single.approved, isTrue);

      await cubit.close();
      await wsClient.dispose();
    },
  );
}

GroupJoinRequest _request(String id) => GroupJoinRequest(
  id: id,
  conversationId: 'group-1',
  groupName: '项目群',
  groupAvatar: 'grid:identicon:1',
  applicantId: 2,
  applicantName: '阿青',
  applicantAvatar: 'identicon:2',
  message: '请通过',
  status: GroupJoinRequestStatus.pending,
  createdAt: DateTime(2026, 8, 31),
);

GroupJoinRequestNotification _notification(String id) =>
    GroupJoinRequestNotification(
      requestId: id,
      conversationId: 'group-1',
      groupName: '项目群',
      applicantId: Int64(2),
      applicantName: '阿青',
      message: '请通过',
      status: 0,
      createdAt: '2026-08-31T00:00:00Z',
    );

class _FakeWsClient extends WsClient {
  _FakeWsClient()
    : super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1/ws/im'),
        tokenProvider: () => null,
      );

  final _controller =
      StreamController<GroupJoinRequestNotification>.broadcast();

  @override
  Stream<GroupJoinRequestNotification> get groupJoinRequestStream =>
      _controller.stream;

  void add(GroupJoinRequestNotification event) => _controller.add(event);

  @override
  Future<void> dispose() => _controller.close();
}
