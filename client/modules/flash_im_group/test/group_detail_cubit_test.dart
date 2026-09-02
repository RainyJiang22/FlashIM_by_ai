import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  test('loads and updates group snapshot', () async {
    final repository = FakeGroupRepository();
    final cubit = GroupDetailCubit(repository: repository, groupId: 'group-1');

    await cubit.load();
    expect(cubit.state.detail?.name, '测试群聊');
    expect(cubit.state.isOwner, isTrue);

    expect(await cubit.updateName('新群名'), isTrue);
    expect(cubit.state.detail?.name, '新群名');

    expect(await cubit.updateNickname(' 项目负责人 '), isTrue);
    expect(cubit.state.detail?.currentUserNickname, '项目负责人');
    expect(repository.updatedNicknames, ['项目负责人']);

    expect(await cubit.updateSettings(true), isTrue);
    expect(cubit.state.detail?.joinApprovalRequired, isTrue);
    await cubit.close();
  });

  test('member invitation and owner dissolve expose terminal state', () async {
    final repository = FakeGroupRepository();
    final cubit = GroupDetailCubit(repository: repository, groupId: 'group-1');
    await cubit.load();

    expect(await cubit.inviteMembers(const [3]), isTrue);
    expect(repository.invitedMemberIds, [
      const [3],
    ]);
    expect(await cubit.dissolveGroup(), isTrue);
    expect(cubit.state.isDissolved, isTrue);
    expect(repository.dissolveCount, 1);
    await cubit.close();
  });

  test('request failure maps stable permission message', () async {
    final cubit = GroupDetailCubit(
      repository: FakeGroupRepository(
        error: const GroupRequestException('group operation is not allowed'),
      ),
      groupId: 'group-1',
    );

    await cubit.load();

    expect(cubit.state.errorMessage, '当前没有执行此操作的权限');
    await cubit.close();
  });

  test('invitation delivery failure maps partial failure message', () async {
    final cubit = GroupDetailCubit(
      repository: FakeGroupRepository(
        error: const GroupRequestException('group invitation delivery failed'),
      ),
      groupId: 'group-1',
    );

    expect(await cubit.inviteMembers(const [3]), isFalse);
    expect(cubit.state.errorMessage, '部分群邀请发送失败，请重试');
    expect(cubit.state.isSaving, isFalse);
    await cubit.close();
  });

  test(
    'announcement, owner transfer and member leave update terminal state',
    () async {
      final ownerRepository = FakeGroupRepository();
      final ownerCubit = GroupDetailCubit(
        repository: ownerRepository,
        groupId: 'group-1',
      );
      await ownerCubit.load();
      expect(await ownerCubit.updateAnnouncement(' 周五发布 '), isTrue);
      expect(ownerCubit.state.detail?.announcement, '周五发布');
      expect(await ownerCubit.transferOwner(2), isTrue);
      expect(ownerCubit.state.detail?.ownerId, 2);
      expect(ownerCubit.state.isOwner, isFalse);
      await ownerCubit.close();

      final memberRepository = FakeGroupRepository(
        detail: groupDetail(isOwner: false),
      );
      final memberCubit = GroupDetailCubit(
        repository: memberRepository,
        groupId: 'group-1',
      );
      await memberCubit.load();
      expect(await memberCubit.leaveGroup(), isTrue);
      expect(memberCubit.state.isLeft, isTrue);
      expect(memberRepository.leaveCount, 1);
      await memberCubit.close();
    },
  );

  test(
    'group info stream merges metadata and reports remote removal',
    () async {
      final wsClient = _FakeWsClient();
      final cubit = GroupDetailCubit(
        repository: FakeGroupRepository(),
        groupId: 'group-1',
        wsClient: wsClient,
      );
      await cubit.load();

      wsClient.addGroupInfo(_groupInfo());
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.detail?.name, '实时群名');
      expect(cubit.state.detail?.announcement, '实时公告');
      expect(cubit.state.detail?.currentUserRole, 'member');

      wsClient.addGroupInfo(_groupInfo(membershipActive: false));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.isRemoved, isTrue);

      await cubit.close();
      expect(wsClient.hasGroupInfoListener, isFalse);
      await wsClient.closeEvents();
    },
  );
}

GroupInfoUpdateNotification _groupInfo({bool membershipActive = true}) =>
    GroupInfoUpdateNotification(
      conversationId: 'group-1',
      name: '实时群名',
      avatar: 'grid:identicon:1,identicon:2',
      ownerId: Int64(2),
      memberCount: 2,
      announcement: '实时公告',
      announcementUpdatedAt: '2026-08-31T08:00:00Z',
      announcementUpdatedBy: Int64(2),
      membershipActive: membershipActive,
      currentUserRole: 'member',
      changeType: 'announcement_updated',
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
