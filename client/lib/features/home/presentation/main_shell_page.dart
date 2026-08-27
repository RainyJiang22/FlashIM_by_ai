import 'dart:async';

import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart' hide FriendUser;
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/app_router.dart';
import '../../mine/presentation/dialogs/password_setup_prompt_dialog.dart';
import '../../mine/presentation/mine_page.dart';
import '../../messages/presentation/messages_placeholder_page.dart';
import 'widgets/home_navigation_bar.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;
  bool _isShowingPasswordPrompt = false;
  bool _isRefreshingProfile = false;
  late final ConversationListCubit _conversationListCubit;
  late final FriendCubit _friendCubit;

  @override
  void initState() {
    super.initState();
    _conversationListCubit = ConversationListCubit(
      repository: context.read<ConversationRepository>(),
      wsClient: context.read<WsClient>(),
    )..loadConversations();
    _friendCubit = FriendCubit(
      repository: context.read<FriendRepository>(),
      wsClient: context.read<WsClient>(),
    )..load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncSessionSideEffects(context.read<SessionCubit>().state);
    });
  }

  @override
  void dispose() {
    _friendCubit.close();
    _conversationListCubit.close();
    super.dispose();
  }

  void _syncSessionSideEffects(SessionState state) {
    final wsClient = context.read<WsClient>();
    if (state.status == SessionStatus.authenticated &&
        state.session?.token.isNotEmpty == true) {
      unawaited(wsClient.connect());
      _refreshProfileIfNeeded(state);
      return;
    }

    if (state.status == SessionStatus.unauthenticated) {
      unawaited(wsClient.disconnect());
    }
  }

  void _refreshProfileIfNeeded(SessionState state) {
    if (_isRefreshingProfile || state.user != null) {
      return;
    }

    _isRefreshingProfile = true;
    unawaited(
      context.read<SessionCubit>().refreshProfile().whenComplete(() {
        _isRefreshingProfile = false;
      }),
    );
  }

  Future<void> _showPasswordPrompt() async {
    if (_isShowingPasswordPrompt) {
      return;
    }

    final sessionCubit = context.read<SessionCubit>();
    _isShowingPasswordPrompt = true;
    final shouldSetNow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordSetupPromptDialog(
        onSkip: () {
          sessionCubit.markPasswordPromptHandled();
          Navigator.of(context).pop(false);
        },
        onSetNow: () {
          sessionCubit.markPasswordPromptHandled();
          Navigator.of(context).pop(true);
        },
      ),
    );
    _isShowingPasswordPrompt = false;
    if (shouldSetNow == true && mounted) {
      await Navigator.of(context).pushNamed(AppRoutes.setPassword);
    }
  }

  Future<void> _openChat(Conversation conversation) async {
    final sessionState = context.read<SessionCubit>().state;
    final session = sessionState.session;
    if (session == null) {
      return;
    }
    await _conversationListCubit.markConversationRead(conversation.id);
    if (!mounted) {
      return;
    }
    final shouldRefresh = await Navigator.of(context).pushNamed(
      AppRoutes.chat,
      arguments: ChatRouteArguments(
        conversation: conversation.copyWith(unreadCount: 0),
        currentUserId: '${session.accountId}',
        currentUserName: sessionState.user?.nickname,
        currentUserAvatar: sessionState.user?.avatar,
      ),
    );
    if (shouldRefresh == true && mounted) {
      await _conversationListCubit.refresh();
    }
  }

  Future<void> _openFriendChat(FriendUser friend) async {
    Conversation? conversation;
    final currentState = _conversationListCubit.state;
    if (currentState is ConversationListLoaded) {
      conversation = _conversationForFriend(
        currentState.conversations,
        friend.accountId,
      );
    }

    if (conversation == null) {
      try {
        final conversations = await context
            .read<ConversationRepository>()
            .getList(limit: 100);
        conversation = _conversationForFriend(conversations, friend.accountId);
        await _conversationListCubit.refresh();
      } catch (_) {
        // The visible fallback below is more useful than a transport detail.
      }
    }

    if (!mounted) {
      return;
    }
    if (conversation == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('会话尚未创建，请稍后重试')));
      return;
    }
    await _openChat(conversation);
  }

  Future<void> _createGroup() async {
    final result = await Navigator.of(context).pushNamed(AppRoutes.createGroup);
    if (result is! Conversation || !mounted) {
      return;
    }
    await _conversationListCubit.refresh();
    if (mounted) {
      await _openChat(result);
    }
  }

  Future<void> _addContact() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<FriendCubit>.value(
          value: _friendCubit,
          child: AddFriendPage(onMessageFriend: _openFriendChat),
        ),
      ),
    );
  }

  Future<void> _openMyGroups() async {
    final result = await Navigator.of(context).pushNamed(AppRoutes.myGroups);
    if (result is Conversation && mounted) {
      await _openChat(result);
    }
  }

  List<Widget> _buildPages() {
    return [
      MessagesPlaceholderPage(
        conversationListCubit: _conversationListCubit,
        onConversationTap: _openChat,
        onCreateGroup: _createGroup,
        onAddContact: _addContact,
      ),
      ContactsPage(
        onMessageFriend: _openFriendChat,
        onOpenGroups: _openMyGroups,
      ),
      const MinePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionCubit, SessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.shouldPromptPasswordSetup !=
              current.shouldPromptPasswordSetup,
      listener: (context, state) async {
        _syncSessionSideEffects(state);

        if (state.status == SessionStatus.unauthenticated) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
          return;
        }

        if (state.shouldPromptPasswordSetup) {
          await _showPasswordPrompt();
        }
      },
      child: BlocProvider<FriendCubit>.value(
        value: _friendCubit,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                WsStatusIndicator(client: context.read<WsClient>()),
                Expanded(child: _buildPages()[_currentIndex]),
              ],
            ),
          ),
          bottomNavigationBar:
              BlocBuilder<ConversationListCubit, ConversationListState>(
                bloc: _conversationListCubit,
                builder: (context, conversationState) {
                  final totalUnread = switch (conversationState) {
                    ConversationListLoaded(:final totalUnread) => totalUnread,
                    _ => 0,
                  };
                  return BlocBuilder<FriendCubit, FriendState>(
                    bloc: _friendCubit,
                    buildWhen: (previous, current) =>
                        previous.pendingRequestCount !=
                        current.pendingRequestCount,
                    builder: (context, friendState) {
                      return HomeNavigationBar(
                        currentIndex: _currentIndex,
                        messageUnreadCount: totalUnread,
                        contactRequestCount: friendState.pendingRequestCount,
                        onDestinationSelected: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                      );
                    },
                  );
                },
              ),
        ),
      ),
    );
  }
}

Conversation? _conversationForFriend(
  List<Conversation> conversations,
  int accountId,
) {
  final value = '$accountId';
  for (final conversation in conversations) {
    if (conversation.isPrivateChat && conversation.peerUserId == value) {
      return conversation;
    }
  }
  return null;
}
