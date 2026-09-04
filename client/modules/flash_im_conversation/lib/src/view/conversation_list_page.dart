import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/conversation.dart';
import '../data/conversation_repository.dart';
import '../logic/conversation_list_cubit.dart';
import '../logic/conversation_list_state.dart';
import 'conversation_tile.dart';

class ConversationListPage extends StatelessWidget {
  const ConversationListPage({
    super.key,
    this.cubit,
    this.onConversationTap,
    this.onlineUserIds = const <int>{},
  });

  final ConversationListCubit? cubit;
  final ValueChanged<Conversation>? onConversationTap;
  final Set<int> onlineUserIds;

  @override
  Widget build(BuildContext context) {
    final providedCubit = cubit;
    final child = ConversationListView(
      onConversationTap: onConversationTap,
      onlineUserIds: onlineUserIds,
    );
    if (providedCubit != null) {
      return BlocProvider<ConversationListCubit>.value(
        value: providedCubit,
        child: child,
      );
    }

    return BlocProvider<ConversationListCubit>(
      create: (context) => ConversationListCubit(
        repository: context.read<ConversationRepository>(),
      )..loadConversations(),
      child: child,
    );
  }
}

class ConversationListView extends StatelessWidget {
  const ConversationListView({
    super.key,
    this.onConversationTap,
    this.onlineUserIds = const <int>{},
  });

  final ValueChanged<Conversation>? onConversationTap;
  final Set<int> onlineUserIds;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationListCubit, ConversationListState>(
      builder: (context, state) {
        return switch (state) {
          ConversationListInitial() || ConversationListLoading() =>
            const Center(child: CircularProgressIndicator()),
          ConversationListError(:final message) => _ErrorView(message: message),
          ConversationListLoaded(:final conversations)
              when conversations.isEmpty =>
            const _EmptyView(),
          ConversationListLoaded() => _ConversationListBody(
            state: state,
            onConversationTap: onConversationTap,
            onlineUserIds: onlineUserIds,
          ),
        };
      },
    );
  }
}

class _ConversationListBody extends StatelessWidget {
  const _ConversationListBody({
    required this.state,
    required this.onlineUserIds,
    this.onConversationTap,
  });

  final ConversationListLoaded state;
  final ValueChanged<Conversation>? onConversationTap;
  final Set<int> onlineUserIds;

  @override
  Widget build(BuildContext context) {
    final conversations = state.conversations;

    return ColoredBox(
      color: FlashPalette.background,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 200) {
            context.read<ConversationListCubit>().loadMore();
          }
          return false;
        },
        child: RefreshIndicator(
          color: FlashPalette.primary,
          backgroundColor: FlashPalette.surface,
          onRefresh: context.read<ConversationListCubit>().refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: conversations.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, index) {
              if (index >= conversations.length - 1) {
                return const SizedBox.shrink();
              }
              return const SizedBox(height: 10);
            },
            itemBuilder: (context, index) {
              if (index >= conversations.length) {
                return _LoadMoreFooter(
                  isLoadingMore: state.isLoadingMore,
                  error: state.loadMoreError,
                );
              }
              final conversation = conversations[index];
              return ConversationTile(
                conversation: conversation,
                isOnline:
                    conversation.isPrivateChat &&
                    onlineUserIds.contains(
                      int.tryParse(conversation.peerUserId ?? ''),
                    ),
                onTap: () => onConversationTap?.call(conversation),
                onLongPress: () =>
                    _confirmHideConversation(context, conversation),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmHideConversation(
    BuildContext context,
    Conversation conversation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除该聊天？'),
        content: const Text('聊天记录会保留。该会话有新消息时，会重新出现在首页消息列表。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('conversation-hide-confirm'),
            style: FilledButton.styleFrom(backgroundColor: FlashPalette.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final hidden = await context
        .read<ConversationListCubit>()
        .hideConversationFromList(conversation.id);
    if (!hidden && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    }
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.isLoadingMore, this.error});

  final bool isLoadingMore;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: FlashPalette.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 64,
      child: Center(
        child: isLoadingMore
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FlashPalette.background,
      child: RefreshIndicator(
        color: FlashPalette.primary,
        backgroundColor: FlashPalette.surface,
        onRefresh: context.read<ConversationListCubit>().refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: FlashPalette.primary,
                size: 38,
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                '暂无会话',
                style: TextStyle(
                  color: FlashPalette.secondaryInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: FlashPalette.mutedInk,
              size: 38,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FlashPalette.secondaryInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: context
                  .read<ConversationListCubit>()
                  .loadConversations,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
