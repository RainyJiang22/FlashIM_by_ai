import 'dart:async';

import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('debounces search and confirms direct join', (tester) async {
    final item = GroupSearchItem(
      conversationId: 'group-1',
      groupNumber: 'group-1',
      name: '项目群',
      avatar: 'grid:identicon:1',
      memberCount: 3,
      joinApprovalRequired: false,
      isMember: false,
      hasPendingRequest: false,
    );
    final repository = FakeGroupRepository(
      searchResults: [item],
      joinResult: const JoinGroupResult(autoApproved: true),
    );
    final wsClient = _FakeWsClient();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<GroupRepository>.value(value: repository),
          RepositoryProvider<WsClient>.value(value: wsClient),
        ],
        child: const MaterialApp(home: SearchGroupPage()),
      ),
    );

    await tester.enterText(find.byKey(const Key('group-search-field')), '项目');
    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.searchKeywords, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(repository.searchKeywords, ['项目']);
    expect(find.text('项目群'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-search-join')));
    await tester.pumpAndSettle();
    expect(find.text('确定加入“项目群”吗？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-join-confirm')));
    await tester.pumpAndSettle();

    expect(repository.joinCalls.single.groupId, 'group-1');
    expect(find.byKey(const Key('group-search-joined')), findsOneWidget);
    await wsClient.dispose();
  });
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

  @override
  Future<void> dispose() => _controller.close();
}
