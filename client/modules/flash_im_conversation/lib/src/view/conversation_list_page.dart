import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/conversation.dart';
import '../data/conversation_repository.dart';
import '../logic/conversation_list_cubit.dart';
import '../logic/conversation_list_state.dart';
import 'conversation_tile.dart';

class ConversationListPage extends StatelessWidget {
  const ConversationListPage({super.key, this.cubit, this.onConversationTap});

  final ConversationListCubit? cubit;
  final ValueChanged<Conversation>? onConversationTap;

  @override
  Widget build(BuildContext context) {
    final providedCubit = cubit;
    final child = ConversationListView(onConversationTap: onConversationTap);
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
  const ConversationListView({super.key, this.onConversationTap});

  final ValueChanged<Conversation>? onConversationTap;

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
          ),
        };
      },
    );
  }
}

class _ConversationListBody extends StatelessWidget {
  const _ConversationListBody({required this.state, this.onConversationTap});

  final ConversationListLoaded state;
  final ValueChanged<Conversation>? onConversationTap;

  @override
  Widget build(BuildContext context) {
    final conversations = state.conversations;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 200) {
          context.read<ConversationListCubit>().loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: context.read<ConversationListCubit>().refresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: conversations.length + (state.hasMore ? 1 : 0),
          separatorBuilder: (_, index) {
            if (index >= conversations.length - 1) {
              return const SizedBox.shrink();
            }
            return const Divider(
              height: 1,
              thickness: 0.8,
              indent: 80,
              color: Color(0xFFE7EEF7),
            );
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
              onTap: () => onConversationTap?.call(conversation),
            );
          },
        ),
      ),
    );
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
              color: const Color(0xFFE35D6A),
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
    return RefreshIndicator(
      onRefresh: context.read<ConversationListCubit>().refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: Text(
              '暂无会话',
              style: TextStyle(
                color: Color(0xFF7A7A7A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFE35D6A),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: context
                  .read<ConversationListCubit>()
                  .loadConversations,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
