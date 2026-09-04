import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart';
import 'package:flash_shared/flash_shared.dart' hide IdenticonAvatar;
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'widgets/message_quick_actions_menu.dart';

class MessagesPlaceholderPage extends StatelessWidget {
  const MessagesPlaceholderPage({
    super.key,
    required this.conversationListCubit,
    required this.onConversationTap,
    required this.onCreateGroup,
    required this.onAddContact,
    required this.onSearch,
    this.onlineUserIds = const <int>{},
  });

  final ConversationListCubit conversationListCubit;
  final ValueChanged<Conversation> onConversationTap;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddContact;
  final VoidCallback onSearch;
  final Set<int> onlineUserIds;

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
              onCreateGroup: onCreateGroup,
              onAddContact: onAddContact,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Material(
                color: FlashPalette.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: const Key('messages-comprehensive-search'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: onSearch,
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FlashPalette.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: FlashPalette.mutedInk,
                          size: 21,
                        ),
                        SizedBox(width: 9),
                        Text(
                          '搜索联系人、群聊和聊天记录',
                          style: TextStyle(color: FlashPalette.mutedInk),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ConversationListPage(
                cubit: conversationListCubit,
                onConversationTap: onConversationTap,
                onlineUserIds: onlineUserIds,
              ),
            ),
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
    required this.onCreateGroup,
    required this.onAddContact,
  });

  final String title;
  final String subtitle;
  final Widget avatar;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wsClient = context.read<WsClient>();

    return DecoratedBox(
      decoration: const BoxDecoration(color: FlashPalette.background),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: FlashPalette.ink,
                    ),
                  ),
                  SizedBox(width: 10),
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
            const SizedBox(width: 12),
            MessageQuickActionsMenu(
              actions: [
                MessageQuickAction(
                  id: 'create_group',
                  label: '发起群聊',
                  icon: Icons.group_add_rounded,
                  onTap: onCreateGroup,
                ),
                MessageQuickAction(
                  id: 'add_contact',
                  label: '添加群/联系人',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: onAddContact,
                ),
              ],
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
      WsConnectionState.authenticated => FlashPalette.success,
      WsConnectionState.connecting ||
      WsConnectionState.authenticating => FlashPalette.warning,
      WsConnectionState.disconnected => FlashPalette.danger,
    };

    return Tooltip(
      message: _label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                _label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
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
