import 'dart:async';

import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('owner approves a pending request and sees handled state', (
    tester,
  ) async {
    final pending = GroupJoinRequest(
      id: 'request-1',
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
    final repository = FakeGroupRepository(
      joinRequests: GroupJoinRequestList(pendingCount: 1, requests: [pending]),
    );
    final wsClient = _FakeWsClient();
    final cubit = GroupNotificationCubit(
      repository: repository,
      wsClient: wsClient,
    );
    await cubit.load();

    await tester.pumpWidget(
      BlocProvider<GroupNotificationCubit>.value(
        value: cubit,
        child: const MaterialApp(home: GroupNotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('阿青'), findsOneWidget);
    expect(find.text('留言：请通过'), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-request-approve')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repository.handleJoinRequestCalls.single.approved, isTrue);
    expect(find.text('已同意'), findsOneWidget);
    expect(cubit.state.pendingCount, 0);
  });

  testWidgets('owner confirms rejection and empty state remains refreshable', (
    tester,
  ) async {
    final pending = _pendingRequest();
    final repository = FakeGroupRepository(
      joinRequests: GroupJoinRequestList(pendingCount: 1, requests: [pending]),
    );
    final cubit = GroupNotificationCubit(
      repository: repository,
      wsClient: _FakeWsClient(),
    );
    await cubit.load();

    await tester.pumpWidget(
      BlocProvider<GroupNotificationCubit>.value(
        value: cubit,
        child: const MaterialApp(home: GroupNotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-request-reject')));
    await tester.pumpAndSettle();
    expect(find.text('确定拒绝“阿青”加入群聊吗？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-request-reject-confirm')));
    await tester.pumpAndSettle();

    expect(repository.handleJoinRequestCalls.single.approved, isFalse);
    expect(find.text('已拒绝'), findsOneWidget);
  });

  testWidgets('shows empty and loading states', (tester) async {
    final repository = _DeferredNotificationRepository();
    final cubit = GroupNotificationCubit(
      repository: repository,
      wsClient: _FakeWsClient(),
    );
    await tester.pumpWidget(
      BlocProvider<GroupNotificationCubit>.value(
        value: cubit,
        child: const MaterialApp(home: GroupNotificationsPage()),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('暂无群通知'), findsOneWidget);

    final future = cubit.load();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.complete();
    await future;
    await tester.pump();
    expect(find.text('暂无群通知'), findsOneWidget);
  });
}

class _DeferredNotificationRepository extends FakeGroupRepository {
  final _completer = Completer<GroupJoinRequestList>();

  @override
  Future<GroupJoinRequestList> getJoinRequests() => _completer.future;

  void complete() => _completer.complete(
    GroupJoinRequestList(pendingCount: 0, requests: const []),
  );
}

GroupJoinRequest _pendingRequest() => GroupJoinRequest(
  id: 'request-2',
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

class _FakeWsClient extends WsClient {
  _FakeWsClient()
    : super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1/ws/im'),
        tokenProvider: () => null,
      );

  @override
  Stream<GroupJoinRequestNotification> get groupJoinRequestStream =>
      const Stream<GroupJoinRequestNotification>.empty();

  @override
  Future<void> dispose() async {}
}
