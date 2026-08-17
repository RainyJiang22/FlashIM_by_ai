import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  test('loads group pages with type filter and searches locally', () async {
    final repository = FakeConversationRepository(
      pages: {
        0: [groupConversation('g1', '项目群')],
        1: [groupConversation('g2', '家人群')],
      },
    );
    final cubit = GroupListCubit(repository: repository, pageSize: 1);

    await cubit.load();
    await cubit.loadMore();
    cubit.updateQuery('家人');

    expect(repository.requestedTypes, [1, 1]);
    expect(repository.requestedOffsets, [0, 1]);
    expect(cubit.state.groups, hasLength(2));
    expect(cubit.state.visibleGroups.single.id, 'g2');
    await cubit.close();
  });

  test('load error is recoverable by refresh', () async {
    final failing = GroupListCubit(
      repository: FakeConversationRepository(listError: StateError('bad')),
    );

    await failing.load();

    expect(failing.state.errorMessage, '群聊列表加载失败');
    expect(failing.state.isLoading, isFalse);
    await failing.close();
  });
}
