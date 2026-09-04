import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeConversationRepository repository;
  final firstConversation = Conversation(
    id: 'conversation-1',
    type: 0,
    peerUserId: '3',
    peerNickname: '橘橙',
    lastMessagePreview: '今天的接口联调先看会话列表。',
    lastMessageAt: DateTime(2026, 3, 29, 9, 12),
    unreadCount: 0,
    createdAt: DateTime(2026, 3, 29, 8),
  );
  final secondConversation = Conversation(
    id: 'conversation-2',
    type: 0,
    peerUserId: '4',
    peerNickname: '藤黄',
    unreadCount: 0,
    createdAt: DateTime(2026, 3, 29, 8, 1),
  );

  blocTest<ConversationListCubit, ConversationListState>(
    'loadConversations emits loading then loaded',
    build: () => ConversationListCubit(
      repository: _FakeConversationRepository(
        pages: {
          0: [firstConversation],
        },
      ),
    ),
    act: (cubit) => cubit.loadConversations(),
    expect: () => [
      const ConversationListLoading(),
      ConversationListLoaded(
        conversations: [firstConversation],
        hasMore: false,
      ),
    ],
  );

  blocTest<ConversationListCubit, ConversationListState>(
    'loadMore appends next page using current length as offset',
    build: () => ConversationListCubit(
      repository: _FakeConversationRepository(
        pages: {
          0: [firstConversation],
          1: [secondConversation],
        },
      ),
      pageSize: 1,
    ),
    act: (cubit) async {
      await cubit.loadConversations();
      await cubit.loadMore();
    },
    expect: () => [
      const ConversationListLoading(),
      ConversationListLoaded(conversations: [firstConversation], hasMore: true),
      ConversationListLoaded(
        conversations: [firstConversation],
        hasMore: true,
        isLoadingMore: true,
      ),
      ConversationListLoaded(
        conversations: [firstConversation, secondConversation],
        hasMore: true,
      ),
    ],
  );

  blocTest<ConversationListCubit, ConversationListState>(
    'hasMore false prevents extra loadMore requests',
    build: () {
      repository = _FakeConversationRepository(
        pages: {
          0: [firstConversation],
        },
      );
      return ConversationListCubit(repository: repository, pageSize: 20);
    },
    act: (cubit) async {
      await cubit.loadConversations();
      await cubit.loadMore();
    },
    verify: (cubit) {
      expect(repository.offsets, [0]);
    },
  );

  blocTest<ConversationListCubit, ConversationListState>(
    'loadMore failure keeps existing conversations',
    build: () => ConversationListCubit(
      repository: _FakeConversationRepository(
        pages: {
          0: [firstConversation],
        },
        failingOffsets: {1},
      ),
      pageSize: 1,
    ),
    act: (cubit) async {
      await cubit.loadConversations();
      await cubit.loadMore();
    },
    expect: () => [
      const ConversationListLoading(),
      ConversationListLoaded(conversations: [firstConversation], hasMore: true),
      ConversationListLoaded(
        conversations: [firstConversation],
        hasMore: true,
        isLoadingMore: true,
      ),
      ConversationListLoaded(
        conversations: [firstConversation],
        hasMore: true,
        loadMoreError: '会话列表加载失败',
      ),
    ],
  );

  blocTest<ConversationListCubit, ConversationListState>(
    'markConversationReadLocally clears unread and totalUnread',
    build: () => ConversationListCubit(
      repository: _FakeConversationRepository(
        pages: {
          0: [firstConversation.copyWith(unreadCount: 5)],
        },
      ),
    ),
    act: (cubit) async {
      await cubit.loadConversations();
      cubit.markConversationReadLocally(firstConversation.id);
    },
    expect: () => [
      const ConversationListLoading(),
      ConversationListLoaded(
        conversations: [firstConversation.copyWith(unreadCount: 5)],
        hasMore: false,
      ),
      ConversationListLoaded(
        conversations: [firstConversation],
        hasMore: false,
      ),
    ],
  );

  blocTest<ConversationListCubit, ConversationListState>(
    'hideConversationFromList removes only the selected item after API success',
    build: () {
      repository = _FakeConversationRepository(
        pages: {
          0: [firstConversation, secondConversation],
        },
      );
      return ConversationListCubit(repository: repository);
    },
    act: (cubit) async {
      await cubit.loadConversations();
      expect(
        await cubit.hideConversationFromList(firstConversation.id),
        isTrue,
      );
    },
    expect: () => [
      const ConversationListLoading(),
      ConversationListLoaded(
        conversations: [firstConversation, secondConversation],
        hasMore: false,
      ),
      ConversationListLoaded(
        conversations: [secondConversation],
        hasMore: false,
      ),
    ],
    verify: (_) => expect(repository.hiddenIds, [firstConversation.id]),
  );

  test(
    'group info stream updates and removes the matching conversation',
    () async {
      final wsClient = _FakeWsClient();
      final group = Conversation(
        id: 'group-1',
        type: 1,
        name: '旧群名',
        unreadCount: 0,
        createdAt: DateTime(2026, 8, 31),
      );
      final cubit = ConversationListCubit(
        repository: _FakeConversationRepository(
          pages: {
            0: [group],
          },
        ),
        wsClient: wsClient,
      );
      await cubit.loadConversations();

      wsClient.addGroupInfo(_groupInfo(name: '新群名', isDissolved: true));
      await Future<void>.delayed(Duration.zero);
      var loaded = cubit.state as ConversationListLoaded;
      expect(loaded.conversations.single.name, '新群名');
      expect(loaded.conversations.single.isDissolved, isTrue);

      wsClient.addGroupInfo(_groupInfo(membershipActive: false));
      await Future<void>.delayed(Duration.zero);
      loaded = cubit.state as ConversationListLoaded;
      expect(loaded.conversations, isEmpty);

      await cubit.close();
      expect(wsClient.hasGroupInfoListener, isFalse);
      await wsClient.closeEvents();
    },
  );

  test(
    'group info does not restore an absent conversation before a new message',
    () async {
      final wsClient = _FakeWsClient();
      final cubit = ConversationListCubit(
        repository: _FakeConversationRepository(pages: const {0: []}),
        wsClient: wsClient,
      );
      await cubit.loadConversations();

      wsClient.addGroupInfo(_groupInfo(name: '隐藏后的新群名'));
      await Future<void>.delayed(Duration.zero);

      final loaded = cubit.state as ConversationListLoaded;
      expect(loaded.conversations, isEmpty);

      await cubit.close();
      await wsClient.closeEvents();
    },
  );

  test(
    'a new message update restores an absent conversation to home',
    () async {
      final cubit = ConversationListCubit(
        repository: _FakeConversationRepository(pages: const {0: []}),
      );
      await cubit.loadConversations();

      cubit.applyConversationUpdate(
        ConversationUpdate(
          conversationId: 'group-1',
          lastMessagePreview: '重新出现',
          lastMessageAt: '2026-09-04T08:30:00Z',
          unreadCount: 1,
          totalUnread: 1,
        ),
      );

      final loaded = cubit.state as ConversationListLoaded;
      expect(loaded.conversations.single.id, 'group-1');
      expect(loaded.conversations.single.lastMessagePreview, '重新出现');
      expect(loaded.totalUnread, 1);

      await cubit.close();
    },
  );
}

GroupInfoUpdateNotification _groupInfo({
  String name = '治理群',
  bool membershipActive = true,
  bool isDissolved = false,
}) => GroupInfoUpdateNotification(
  conversationId: 'group-1',
  name: name,
  avatar: 'grid:identicon:1,identicon:2',
  memberCount: 2,
  isDissolved: isDissolved,
  membershipActive: membershipActive,
  currentUserRole: 'member',
  changeType: 'name_updated',
);

class _FakeWsClient extends WsClient {
  _FakeWsClient()
    : super(
        config: ImConfig(wsUrl: 'ws://127.0.0.1:9600/ws/im'),
        tokenProvider: () => null,
      );

  final _groupInfo = StreamController<GroupInfoUpdateNotification>.broadcast();

  @override
  Stream<GroupInfoUpdateNotification> get groupInfoUpdateStream =>
      _groupInfo.stream;

  bool get hasGroupInfoListener => _groupInfo.hasListener;

  void addGroupInfo(GroupInfoUpdateNotification update) =>
      _groupInfo.add(update);

  Future<void> closeEvents() => _groupInfo.close();
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    required this.pages,
    this.failingOffsets = const <int>{},
  });

  final Map<int, List<Conversation>> pages;
  final Set<int> failingOffsets;
  final List<int> offsets = <int>[];
  final List<String> hiddenIds = <String>[];

  @override
  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Conversation>> getList({
    int limit = 20,
    int offset = 0,
    int? type,
  }) async {
    offsets.add(offset);
    if (failingOffsets.contains(offset)) {
      throw StateError('network failed');
    }
    return pages[offset] ?? const <Conversation>[];
  }

  @override
  Future<Conversation> getById(String id) async {
    return pages.values
        .expand((items) => items)
        .firstWhere((conversation) => conversation.id == id);
  }

  @override
  Future<Conversation> getPrivateByPeerId(int peerUserId) async {
    return pages.values
        .expand((items) => items)
        .firstWhere((conversation) => conversation.peerUserId == '$peerUserId');
  }

  @override
  Future<void> hideFromList(String id) async {
    hiddenIds.add(id);
  }

  @override
  Future<void> markRead(String id) async {}
}
