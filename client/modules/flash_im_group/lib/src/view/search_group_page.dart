import 'dart:async';

import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/group_discovery.dart';
import '../data/group_repository.dart';
import '../logic/group_search_cubit.dart';
import '../logic/group_search_state.dart';
import 'widgets/group_search_result_tile.dart';

class SearchGroupPage extends StatelessWidget {
  const SearchGroupPage({super.key, this.onJoined});

  final ValueChanged<Conversation>? onJoined;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GroupSearchCubit(
        repository: context.read<GroupRepository>(),
        wsClient: context.read<WsClient>(),
      ),
      child: _SearchGroupView(onJoined: onJoined),
    );
  }
}

class _SearchGroupView extends StatefulWidget {
  const _SearchGroupView({this.onJoined});

  final ValueChanged<Conversation>? onJoined;

  @override
  State<_SearchGroupView> createState() => _SearchGroupViewState();
}

class _SearchGroupViewState extends State<_SearchGroupView> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupSearchCubit, GroupSearchState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.lastJoinResult != current.lastJoinResult,
      listener: (context, state) {
        final error = state.errorMessage;
        final result = state.lastJoinResult;
        if (error != null) {
          _showMessage(error);
        } else if (result != null) {
          if (result.autoApproved) {
            _showMessage('已成功加入群聊');
            final conversation = result.conversation;
            if (conversation != null) widget.onJoined?.call(conversation);
          } else {
            _showMessage('申请已发送，等待群主审批');
          }
        }
        context.read<GroupSearchCubit>().clearFeedback();
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('搜索群聊')),
          backgroundColor: FlashPalette.background,
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: const BoxDecoration(
                  color: FlashPalette.background,
                  border: Border(
                    bottom: BorderSide(color: FlashPalette.border),
                  ),
                ),
                child: TextField(
                  key: const Key('group-search-field'),
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '搜索群名或群号',
                    prefixIcon: Icon(Icons.search_rounded),
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                  onChanged: _onChanged,
                  onSubmitted: context.read<GroupSearchCubit>().search,
                ),
              ),
              if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _body(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(GroupSearchState state) {
    if (state.keyword.isEmpty) {
      return const Center(
        child: Text(
          '输入群名或完整群号查找群聊',
          style: TextStyle(color: FlashPalette.secondaryInk),
        ),
      );
    }
    if (!state.isLoading && state.items.isEmpty) {
      return const Center(
        child: Text(
          '没有找到相关群聊',
          style: TextStyle(color: FlashPalette.secondaryInk),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 88),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return GroupSearchResultTile(
          item: item,
          isActing: state.actionGroupId == item.conversationId,
          onTap: state.actionGroupId == null ? () => _confirmJoin(item) : null,
        );
      },
    );
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => context.read<GroupSearchCubit>().search(value),
    );
  }

  Future<void> _confirmJoin(GroupSearchItem item) async {
    if (item.joinApprovalRequired) {
      final message = await _showApplicationDialog(item);
      if (message != null && mounted) {
        await context.read<GroupSearchCubit>().join(item, message: message);
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('加入群聊'),
        content: Text('确定加入“${item.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('group-join-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('加入'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<GroupSearchCubit>().join(item);
    }
  }

  Future<String?> _showApplicationDialog(GroupSearchItem item) {
    final messageController = TextEditingController(text: '请求加入群聊');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('申请加入群聊'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FlashPalette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FlashPalette.border),
                  ),
                  child: Row(
                    children: [
                      GroupAvatarWidget(
                        avatar: item.avatar,
                        seed: item.conversationId,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.memberCount} 人 · 群号 ${item.groupNumber}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlashPalette.secondaryInk,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('group-application-message'),
                  controller: messageController,
                  maxLength: 200,
                  maxLines: 3,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    hintText: '填写申请留言',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('group-application-submit'),
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(messageController.text.trim()),
              child: const Text('发送申请'),
            ),
          ],
        ),
      ),
    ).whenComplete(messageController.dispose);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
