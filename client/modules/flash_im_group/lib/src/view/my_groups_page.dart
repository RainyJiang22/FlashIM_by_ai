import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../logic/group_list_cubit.dart';
import '../logic/group_list_state.dart';
import 'widgets/group_feedback_view.dart';

class MyGroupsPage extends StatelessWidget {
  const MyGroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          GroupListCubit(repository: context.read<ConversationRepository>())
            ..load(),
      child: const _MyGroupsView(),
    );
  }
}

class _MyGroupsView extends StatelessWidget {
  const _MyGroupsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的群聊')),
      backgroundColor: FlashPalette.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('my-groups-search'),
              onChanged: context.read<GroupListCubit>().updateQuery,
              decoration: const InputDecoration(
                hintText: '搜索群聊',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<GroupListCubit, GroupListState>(
              builder: (context, state) {
                if (state.isLoading && state.groups.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.errorMessage != null && state.groups.isEmpty) {
                  return GroupFeedbackView(
                    icon: Icons.cloud_off_rounded,
                    message: state.errorMessage!,
                    actionLabel: '重试',
                    onAction: context.read<GroupListCubit>().load,
                  );
                }
                if (state.visibleGroups.isEmpty) {
                  return const GroupFeedbackView(
                    icon: Icons.groups_outlined,
                    message: '暂无群聊',
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 160) {
                      context.read<GroupListCubit>().loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: context.read<GroupListCubit>().refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount:
                          state.visibleGroups.length +
                          (state.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == state.visibleGroups.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final group = state.visibleGroups[index];
                        return ConversationTile(
                          conversation: group,
                          onTap: () => Navigator.of(context).pop(group),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
