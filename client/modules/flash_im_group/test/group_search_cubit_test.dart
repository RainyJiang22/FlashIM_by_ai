import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  test(
    'latest search response wins when requests finish out of order',
    () async {
      final repository = _DeferredSearchRepository();
      final cubit = GroupSearchCubit(repository: repository);

      final first = cubit.search('旧关键词');
      final second = cubit.search('新关键词');
      repository.complete('新关键词', [_group('new', '新群')]);
      await second;
      repository.complete('旧关键词', [_group('old', '旧群')]);
      await first;

      expect(cubit.state.keyword, '新关键词');
      expect(cubit.state.items.single.conversationId, 'new');
      await cubit.close();
    },
  );

  test(
    'join updates four-state flags and handled ws event reconciles them',
    () async {
      final wsClient = _FakeWsClient();
      final item = _group('group-1', '项目群', approvalRequired: true);
      final repository = FakeGroupRepository(
        searchResults: [item],
        joinResult: const JoinGroupResult(
          autoApproved: false,
          requestId: 'request-1',
        ),
      );
      final cubit = GroupSearchCubit(
        repository: repository,
        wsClient: wsClient,
      );

      await cubit.search('项目');
      expect(await cubit.join(item, message: '请通过'), isTrue);
      expect(cubit.state.items.single.hasPendingRequest, isTrue);
      expect(repository.joinCalls.single.message, '请通过');

      wsClient.add(
        GroupJoinRequestNotification(
          requestId: 'request-1',
          conversationId: 'group-1',
          applicantId: Int64(2),
          status: 1,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.items.single.isMember, isTrue);
      expect(cubit.state.items.single.hasPendingRequest, isFalse);

      await cubit.close();
      await wsClient.dispose();
    },
  );

  test('empty search resets state and join guards invalid actions', () async {
    final member = _group('member', '已加入群').copyWith(isMember: true);
    final repository = FakeGroupRepository(searchResults: [member]);
    final cubit = GroupSearchCubit(repository: repository);

    await cubit.search('  已加入  ');
    expect(cubit.state.keyword, '已加入');
    expect(await cubit.join(member), isFalse);
    expect(repository.joinCalls, isEmpty);

    await cubit.search('   ');
    expect(cubit.state, const GroupSearchState());
    await cubit.close();
  });

  test('search and join failures expose actionable messages', () async {
    final searchCubit = GroupSearchCubit(
      repository: FakeGroupRepository(error: StateError('offline')),
    );
    await searchCubit.search('项目');
    expect(searchCubit.state.errorMessage, '网络异常，请稍后重试');
    searchCubit.clearFeedback();
    expect(searchCubit.state.errorMessage, isNull);
    await searchCubit.close();

    final item = _group('group-1', '项目群');
    final joinCubit = GroupSearchCubit(
      repository: FakeGroupRepository(
        searchResults: [item],
        error: const GroupRequestException('group member limit reached'),
      ),
    );
    expect(await joinCubit.join(item), isFalse);
    expect(joinCubit.state.errorMessage, '该群成员已满');
    expect(joinCubit.state.actionGroupId, isNull);
    await joinCubit.close();
  });

  test('pending and rejected ws events do not grant membership', () async {
    final wsClient = _FakeWsClient();
    final item = _group('group-1', '项目群');
    final cubit = GroupSearchCubit(
      repository: FakeGroupRepository(searchResults: [item]),
      wsClient: wsClient,
    );
    await cubit.search('项目');

    wsClient.add(
      GroupJoinRequestNotification(conversationId: 'group-1', status: 0),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.items.single.isMember, isFalse);

    wsClient.add(
      GroupJoinRequestNotification(conversationId: 'group-1', status: 2),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.items.single.isMember, isFalse);
    expect(cubit.state.items.single.hasPendingRequest, isFalse);

    await cubit.close();
    await wsClient.dispose();
  });
}

GroupSearchItem _group(
  String id,
  String name, {
  bool approvalRequired = false,
}) => GroupSearchItem(
  conversationId: id,
  groupNumber: id,
  name: name,
  avatar: 'grid:identicon:1',
  memberCount: 2,
  joinApprovalRequired: approvalRequired,
  isMember: false,
  hasPendingRequest: false,
);

class _DeferredSearchRepository extends FakeGroupRepository {
  final _completers = <String, Completer<List<GroupSearchItem>>>{};

  @override
  Future<List<GroupSearchItem>> searchGroups(String keyword) =>
      (_completers[keyword] ??= Completer<List<GroupSearchItem>>()).future;

  void complete(String keyword, List<GroupSearchItem> items) {
    _completers[keyword]!.complete(items);
  }
}

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
