import 'dart:async';

import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_search/flash_im_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'comprehensive search emits each section and tolerates one failure',
    () async {
      final repository = _DeferredRepository();
      final history = _MemoryHistoryStore();
      final cubit = SearchCubit(repository: repository, historyStore: history);

      final pending = cubit.search(' 发布 ');
      expect(cubit.state.pendingSections, SearchSection.values.toSet());

      repository.friends.complete([_friend(2)]);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.friends.single.accountId, 2);
      expect(cubit.state.isPending(SearchSection.friends), isFalse);
      expect(cubit.state.isPending(SearchSection.messages), isTrue);

      repository.groups.completeError(StateError('group failed'));
      repository.messages.complete([_group()]);
      await pending;

      expect(cubit.state.hasFailed(SearchSection.groups), isTrue);
      expect(cubit.state.messageGroups.single.matchCount, 2);
      expect(cubit.state.pendingSections, isEmpty);
      expect(history.values, ['发布']);
      await cubit.close();
    },
  );

  test('new generation discards older responses', () async {
    final repository = _SequencedRepository();
    final cubit = SearchCubit(
      repository: repository,
      historyStore: _MemoryHistoryStore(),
    );

    unawaited(cubit.search('old'));
    unawaited(cubit.search('new'));
    repository.completeAll('new', friendId: 3);
    await Future<void>.delayed(Duration.zero);
    repository.completeAll('old', friendId: 2);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.keyword, 'new');
    expect(cubit.state.friends.single.accountId, 3);
    await cubit.close();
  });

  test('conversation search clears blank input and exposes failures', () async {
    final repository = _ImmediateRepository(failConversation: true);
    final cubit = ConversationSearchCubit(
      repository: repository,
      conversationId: 'group-1',
    );

    await cubit.search('发布');
    expect(cubit.state.hasError, isTrue);
    await cubit.search(' ');
    expect(cubit.state, const ConversationSearchState());
    await cubit.close();
  });
}

class _DeferredRepository implements SearchRepository {
  final friends = Completer<List<FriendUser>>();
  final groups = Completer<List<Conversation>>();
  final messages = Completer<List<MessageSearchGroup>>();

  @override
  Future<List<FriendUser>> searchFriends(String query) => friends.future;

  @override
  Future<List<Conversation>> searchJoinedGroups(String query) => groups.future;

  @override
  Future<List<MessageSearchGroup>> searchMessages(String query) =>
      messages.future;

  @override
  Future<List<Message>> searchConversationMessages({
    required String conversationId,
    required String query,
  }) async => [];
}

class _SequencedRepository implements SearchRepository {
  final _friends = <String, Completer<List<FriendUser>>>{};
  final _groups = <String, Completer<List<Conversation>>>{};
  final _messages = <String, Completer<List<MessageSearchGroup>>>{};

  @override
  Future<List<FriendUser>> searchFriends(String query) =>
      (_friends[query] ??= Completer()).future;

  @override
  Future<List<Conversation>> searchJoinedGroups(String query) =>
      (_groups[query] ??= Completer()).future;

  @override
  Future<List<MessageSearchGroup>> searchMessages(String query) =>
      (_messages[query] ??= Completer()).future;

  @override
  Future<List<Message>> searchConversationMessages({
    required String conversationId,
    required String query,
  }) async => [];

  void completeAll(String query, {required int friendId}) {
    _friends[query]!.complete([_friend(friendId)]);
    _groups[query]!.complete([]);
    _messages[query]!.complete([]);
  }
}

class _ImmediateRepository implements SearchRepository {
  _ImmediateRepository({this.failConversation = false});

  final bool failConversation;

  @override
  Future<List<FriendUser>> searchFriends(String query) async => [];

  @override
  Future<List<Conversation>> searchJoinedGroups(String query) async => [];

  @override
  Future<List<MessageSearchGroup>> searchMessages(String query) async => [];

  @override
  Future<List<Message>> searchConversationMessages({
    required String conversationId,
    required String query,
  }) async {
    if (failConversation) throw StateError('failed');
    return [];
  }
}

class _MemoryHistoryStore implements SearchHistoryStore {
  List<String> values = [];

  @override
  Future<void> clear() async => values = [];

  @override
  Future<List<String>> load() async => values;

  @override
  Future<List<String>> save(String query) async {
    values = [query, ...values.where((item) => item != query)];
    return values;
  }
}

FriendUser _friend(int id) => FriendUser(
  accountId: id,
  nickname: '好友$id',
  avatar: 'identicon:$id',
  signature: '',
  relationStatus: 'friend',
);

MessageSearchGroup _group() => MessageSearchGroup(
  conversation: Conversation(
    id: 'group-1',
    type: 1,
    name: '项目群',
    unreadCount: 0,
    createdAt: DateTime(2026),
  ),
  matchCount: 2,
  messages: [
    Message(
      id: 'message-1',
      conversationId: 'group-1',
      senderId: '2',
      senderName: '阿青',
      seq: 1,
      content: '发布',
      status: MessageStatus.sent,
      createdAt: DateTime(2026),
    ),
  ],
);
