import 'dart:async';

import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/search_repository.dart';
import '../logic/conversation_search_cubit.dart';
import '../logic/conversation_search_state.dart';
import 'message_detail_page.dart';
import 'single_message_page.dart';

class ConversationSearchPage extends StatelessWidget {
  const ConversationSearchPage({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ConversationSearchCubit(
        repository: context.read<SearchRepository>(),
        conversationId: conversation.id,
      ),
      child: _ConversationSearchView(conversation: conversation),
    );
  }
}

class _ConversationSearchView extends StatefulWidget {
  const _ConversationSearchView({required this.conversation});

  final Conversation conversation;

  @override
  State<_ConversationSearchView> createState() =>
      _ConversationSearchViewState();
}

class _ConversationSearchViewState extends State<_ConversationSearchView> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('查找聊天内容')),
      backgroundColor: FlashPalette.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              key: const Key('conversation-search-field'),
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索 ${widget.conversation.displayName} 的消息',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: _onChanged,
              onSubmitted: context.read<ConversationSearchCubit>().search,
            ),
          ),
          Expanded(
            child:
                BlocBuilder<ConversationSearchCubit, ConversationSearchState>(
                  builder: (context, state) {
                    if (state.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.hasError) {
                      return _StatusView(
                        text: '搜索失败，请重试',
                        action: () => context
                            .read<ConversationSearchCubit>()
                            .search(state.keyword),
                      );
                    }
                    if (!state.hasSearched) {
                      return const _StatusView(text: '输入关键词查找聊天内容');
                    }
                    if (state.messages.isEmpty) {
                      return const _StatusView(text: '没有找到相关消息');
                    }
                    return ListView.separated(
                      itemCount: state.messages.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 76),
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        return MessageResultTile(
                          message: message,
                          keyword: state.keyword,
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => SingleMessagePage(
                                message: message,
                                keyword: state.keyword,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => context.read<ConversationSearchCubit>().search(value),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.text, this.action});

  final String text;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(color: FlashPalette.secondaryInk)),
          if (action != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: action, child: const Text('重试')),
          ],
        ],
      ),
    );
  }
}
