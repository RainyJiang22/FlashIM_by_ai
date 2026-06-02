import 'package:flutter/material.dart';

import '../../../../core/config/playground_api_config.dart';
import '../../../../core/network/dio_factory.dart';
import '../data/conversation_api.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation_entity.dart';
import 'widgets/conversation_list_tile.dart';

class ConversationPlaygroundPage extends StatefulWidget {
  const ConversationPlaygroundPage({
    super.key,
    ConversationRepository? repository,
  }) : _repository = repository;

  final ConversationRepository? _repository;

  @override
  State<ConversationPlaygroundPage> createState() =>
      _ConversationPlaygroundPageState();
}

class _ConversationPlaygroundPageState
    extends State<ConversationPlaygroundPage> {
  late final ConversationRepository _repository;
  late Future<List<ConversationEntity>> _requestFuture;

  @override
  void initState() {
    super.initState();
    _repository =
        widget._repository ??
        RemoteConversationRepository(
          request: DioConversationApi(
            dio: DioFactory.create(baseUrl: PlaygroundApiConfig.defaultBaseUrl),
          ),
        );
    _requestFuture = _repository.fetchConversations();
  }

  Future<void> _reload() async {
    final future = _repository.fetchConversations();
    setState(() {
      _requestFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConversationEntity>>(
      future: _requestFuture,
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? const <ConversationEntity>[];

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            centerTitle: true,
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFF111111)),
            title: Text(
              '微信(${conversations.length})',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              IconButton(
                onPressed: _reload,
                icon: const Icon(
                  Icons.search,
                  color: Color(0xFF111111),
                  size: 32,
                ),
              ),
              IconButton(
                onPressed: _reload,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF111111),
                  size: 34,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: _buildBody(snapshot, conversations),
          // bottomNavigationBar: ConversationBottomNavigationBar(
          //   unreadCount: conversations.length,
          // ),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<ConversationEntity>> snapshot,
    List<ConversationEntity> conversations,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF07C160)),
      );
    }

    if (snapshot.hasError) {
      return _ConversationErrorView(
        message: snapshot.error.toString(),
        onRetry: _reload,
      );
    }

    if (conversations.isEmpty) {
      return _ConversationEmptyView(onRetry: _reload);
    }

    return RefreshIndicator(
      color: const Color(0xFF07C160),
      onRefresh: _reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: conversations.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 84, color: Color(0xFFF0F0F0)),
        itemBuilder: (context, index) {
          final item = conversations[index];
          return ConversationListTile(conversation: item);
        },
      ),
    );
  }
}

class _ConversationEmptyView extends StatelessWidget {
  const _ConversationEmptyView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '暂无会话',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

class _ConversationErrorView extends StatelessWidget {
  const _ConversationErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '会话加载失败',
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
