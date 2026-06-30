import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MessagesPlaceholderPage extends StatelessWidget {
  const MessagesPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, sessionState) {
        final user = sessionState.user;
        final fallbackName = sessionState.session == null
            ? 'Flash IM'
            : '用户 ${sessionState.session!.accountId}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MessagesHeader(
              title: user?.nickname.trim().isNotEmpty == true
                  ? user!.nickname
                  : fallbackName,
              subtitle: user?.signature.trim().isNotEmpty == true
                  ? user!.signature
                  : '消息同步状态',
              avatar: user == null
                  ? IdenticonAvatar(
                      seed: '${sessionState.session?.accountId ?? 'guest'}',
                      size: 48,
                      borderRadius: BorderRadius.circular(10),
                    )
                  : UserAvatar(user: user, size: 48),
            ),
            const Expanded(child: Center(child: Text('消息页暂未开放'))),
          ],
        );
      },
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader({
    required this.title,
    required this.subtitle,
    required this.avatar,
  });

  final String title;
  final String subtitle;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wsClient = context.read<WsClient>();

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE7EEF7), width: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StreamBuilder<WsConnectionState>(
              stream: wsClient.stateStream,
              initialData: wsClient.state,
              builder: (context, snapshot) {
                return _StatusBadge(
                  state: snapshot.data ?? WsConnectionState.disconnected,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final WsConnectionState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      WsConnectionState.authenticated => const Color(0xFF07C160),
      WsConnectionState.connecting ||
      WsConnectionState.authenticating => const Color(0xFFFFB020),
      WsConnectionState.disconnected => const Color(0xFFE35D6A),
    };

    return Tooltip(
      message: _label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String get _label => switch (state) {
    WsConnectionState.authenticated => '已连接',
    WsConnectionState.connecting => '正在连接',
    WsConnectionState.authenticating => '正在认证',
    WsConnectionState.disconnected => '已断开',
  };
}
