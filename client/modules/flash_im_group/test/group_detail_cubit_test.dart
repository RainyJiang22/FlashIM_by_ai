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
}
