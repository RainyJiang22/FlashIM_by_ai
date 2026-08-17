import 'package:bloc_test/bloc_test.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  late FakeConversationRepository repository;
  test('loads, searches and protects locked member', () async {
    final cubit = CreateGroupCubit(
      friendRepository: FakeFriendRepository(friends: friends),
      conversationRepository: FakeConversationRepository(),
      initialMembers: [friends.first],
    );

    await cubit.loadFriends();
    cubit.toggleFriend(friends.first);
    expect(cubit.state.selectedIds, {2});

    cubit.updateQuery('orange');
    expect(cubit.state.visibleFriends, [friends[2]]);
    await cubit.close();
  });

  blocTest<CreateGroupCubit, CreateGroupState>(
    'requires two members and creates group with generated name',
    build: () {
      repository = FakeConversationRepository(
        created: groupConversation('g1', '阿青、白露'),
      );
      return CreateGroupCubit(
        friendRepository: FakeFriendRepository(friends: friends),
        conversationRepository: repository,
      );
    },
    act: (cubit) async {
      await cubit.loadFriends();
      expect(await cubit.createGroup(), isNull);
      cubit.toggleFriend(friends[0]);
      cubit.toggleFriend(friends[1]);
      final created = await cubit.createGroup();
      expect(created?.id, 'g1');
    },
    verify: (cubit) {
      expect(repository.createdName, '阿青、白露');
      expect(repository.createdMemberIds, [2, 3]);
    },
  );

  test('creation failure keeps selection and exposes message', () async {
    final repository = FakeConversationRepository(
      createError: StateError('failed'),
    );
    final cubit = CreateGroupCubit(
      friendRepository: FakeFriendRepository(friends: friends),
      conversationRepository: repository,
    );
    await cubit.loadFriends();
    cubit.toggleFriend(friends[0]);
    cubit.toggleFriend(friends[1]);

    expect(await cubit.createGroup(), isNull);
    expect(cubit.state.selectedIds, {2, 3});
    expect(cubit.state.errorMessage, '创建群聊失败，请稍后重试');
    await cubit.close();
  });

  test('more than three members uses first three names plus 等', () async {
    final repository = FakeConversationRepository(
      created: groupConversation('g2', '阿青、白露、橙子等'),
    );
    final cubit = CreateGroupCubit(
      friendRepository: FakeFriendRepository(friends: friends),
      conversationRepository: repository,
    );
    await cubit.loadFriends();
    for (final friend in friends) {
      cubit.toggleFriend(friend);
    }

    await cubit.createGroup();

    expect(repository.createdName, '阿青、白露、橙子等');
    await cubit.close();
  });

  test(
    'generated group name truncates Unicode safely to 100 code points',
    () async {
      final longFriends = List.generate(
        3,
        (index) => FriendUser(
          accountId: index + 10,
          nickname: '${'群'.padRight(48, '聊')}😀$index',
          avatar: '',
          signature: '',
          relationStatus: 'friend',
        ),
      );
      final repository = FakeConversationRepository(
        created: groupConversation('g3', '长群名'),
      );
      final cubit = CreateGroupCubit(
        friendRepository: FakeFriendRepository(friends: longFriends),
        conversationRepository: repository,
      );
      await cubit.loadFriends();
      for (final friend in longFriends) {
        cubit.toggleFriend(friend);
      }

      await cubit.createGroup();

      expect(repository.createdName!.runes.length, 100);
      expect(repository.createdName, isNot(contains('\uFFFD')));
      await cubit.close();
    },
  );
}
