import 'package:bloc_test/bloc_test.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
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
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    required this.pages,
    this.failingOffsets = const <int>{},
  });

  final Map<int, List<Conversation>> pages;
  final Set<int> failingOffsets;
  final List<int> offsets = <int>[];

  @override
  Future<List<Conversation>> getList({int limit = 20, int offset = 0}) async {
    offsets.add(offset);
    if (failingOffsets.contains(offset)) {
      throw StateError('network failed');
    }
    return pages[offset] ?? const <Conversation>[];
  }
}
