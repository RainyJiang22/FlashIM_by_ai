import 'dart:async';

import 'package:flash_starter/flash_starter.dart';
import 'package:flash_auth/flash_auth.dart';
import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_core/flash_im_core.dart' show WsClient;
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/home/presentation/main_shell_page.dart';

abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const home = '/home';
  static const editProfile = '/mine/profile/edit';
  static const setPassword = '/mine/password/set';
  static const changePassword = '/mine/password/change';
  static const chat = '/chat';
  static const createGroup = '/group/create';
  static const myGroups = '/group/list';
  static const privateChatDetails = '/chat/private/details';
  static const groupDetails = '/chat/group/details';
}

class CreateGroupRouteArguments {
  const CreateGroupRouteArguments({this.initialMembers = const []});

  final List<FriendUser> initialMembers;
}

class PrivateChatDetailsRouteArguments {
  const PrivateChatDetailsRouteArguments({
    required this.friend,
    required this.currentUserId,
    this.currentUserName,
    this.currentUserAvatar,
  });

  final FriendUser friend;
  final String currentUserId;
  final String? currentUserName;
  final String? currentUserAvatar;
}

class ChatRouteArguments {
  const ChatRouteArguments({
    required this.conversation,
    required this.currentUserId,
    this.currentUserName,
    this.currentUserAvatar,
  });

  final Conversation conversation;
  final String currentUserId;
  final String? currentUserName;
  final String? currentUserAvatar;
}

class GroupDetailsRouteArguments {
  const GroupDetailsRouteArguments({required this.conversation});

  final Conversation conversation;
}

Route<dynamic>? onGenerateAppRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.startup:
      return MaterialPageRoute<void>(
        builder: (context) => AppStarterPage(
          options: AppStarterOptions(
            controller: context.read<AppStarterController>(),
            routes: const AppStarterRoutes(
              loginRouteName: AppRoutes.login,
              homeRouteName: AppRoutes.home,
            ),
            branding: AppStarterBranding(
              logo: Image.asset(
                'assets/branding/flash_im_logo_alpha.png',
                width: 132,
              ),
              title: 'Flash IM',
              idleSubtitle: '轻量即时通讯',
              loadingSubtitle: '正在恢复登录状态...',
            ),
          ),
        ),
        settings: settings,
      );
    case AppRoutes.login:
      return MaterialPageRoute<void>(
        builder: (context) => LoginPage(
          homeRouteName: AppRoutes.home,
          onLoginSuccess: context.read<SessionCubit>().completeLogin,
        ),
        settings: settings,
      );
    case AppRoutes.home:
      return MaterialPageRoute<void>(
        builder: (_) => const MainShellPage(),
        settings: settings,
      );
    case AppRoutes.editProfile:
      return MaterialPageRoute<void>(
        builder: (_) => const EditProfilePage(),
        settings: settings,
      );
    case AppRoutes.setPassword:
      return MaterialPageRoute<void>(
        builder: (_) => const SetPasswordPage(),
        settings: settings,
      );
    case AppRoutes.changePassword:
      return MaterialPageRoute<void>(
        builder: (_) => const ChangePasswordPage(),
        settings: settings,
      );
    case AppRoutes.chat:
      final args = settings.arguments;
      if (args is! ChatRouteArguments) {
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('聊天参数异常'))),
          settings: settings,
        );
      }
      return MaterialPageRoute<void>(
        builder: (context) => ChatPage(
          conversation: args.conversation,
          currentUserId: args.currentUserId,
          currentUserName: args.currentUserName,
          currentUserAvatar: args.currentUserAvatar,
          onDetailsTap: args.conversation.isPrivateChat
              ? () async {
                  final peerId = int.tryParse(
                    args.conversation.peerUserId ?? '',
                  );
                  if (peerId == null) {
                    return null;
                  }
                  final group = await Navigator.of(context)
                      .pushNamed<Conversation>(
                        AppRoutes.privateChatDetails,
                        arguments: PrivateChatDetailsRouteArguments(
                          friend: FriendUser(
                            accountId: peerId,
                            nickname: args.conversation.peerNickname ?? '',
                            avatar: args.conversation.peerAvatar ?? '',
                            signature: '',
                            relationStatus: 'friend',
                          ),
                          currentUserId: args.currentUserId,
                          currentUserName: args.currentUserName,
                          currentUserAvatar: args.currentUserAvatar,
                        ),
                      );
                  if (group != null && context.mounted) {
                    await Navigator.of(context).pushReplacementNamed(
                      AppRoutes.chat,
                      arguments: ChatRouteArguments(
                        conversation: group,
                        currentUserId: args.currentUserId,
                        currentUserName: args.currentUserName,
                        currentUserAvatar: args.currentUserAvatar,
                      ),
                    );
                  }
                  return null;
                }
              : () async {
                  final result = await Navigator.of(context)
                      .pushNamed<GroupDetailsResult>(
                        AppRoutes.groupDetails,
                        arguments: GroupDetailsRouteArguments(
                          conversation: args.conversation,
                        ),
                      );
                  if ((result?.outcome == GroupDetailsOutcome.left ||
                          result?.outcome == GroupDetailsOutcome.removed) &&
                      context.mounted) {
                    Navigator.of(context).pop(true);
                    return null;
                  }
                  return result?.conversation;
                },
          onAcceptGroupInvitation: (invitationId) async {
            final group = await context
                .read<GroupRepository>()
                .acceptInvitation(invitationId);
            if (!context.mounted) return;
            unawaited(
              Navigator.of(context).pushNamed(
                AppRoutes.chat,
                arguments: ChatRouteArguments(
                  conversation: group,
                  currentUserId: args.currentUserId,
                  currentUserName: args.currentUserName,
                  currentUserAvatar: args.currentUserAvatar,
                ),
              ),
            );
          },
        ),
        settings: settings,
      );
    case AppRoutes.createGroup:
      final args = settings.arguments;
      final initialMembers = args is CreateGroupRouteArguments
          ? args.initialMembers
          : const <FriendUser>[];
      return MaterialPageRoute<Conversation>(
        builder: (_) => CreateGroupPage(initialMembers: initialMembers),
        settings: settings,
      );
    case AppRoutes.myGroups:
      return MaterialPageRoute<Conversation>(
        builder: (_) => const MyGroupsPage(),
        settings: settings,
      );
    case AppRoutes.privateChatDetails:
      final args = settings.arguments;
      if (args is! PrivateChatDetailsRouteArguments) {
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('聊天参数异常'))),
          settings: settings,
        );
      }
      return MaterialPageRoute<Conversation>(
        builder: (context) => PrivateChatDetailsPage(
          friend: args.friend,
          onInviteMore: (friend) async {
            final group = await Navigator.of(context).pushNamed<Conversation>(
              AppRoutes.createGroup,
              arguments: CreateGroupRouteArguments(initialMembers: [friend]),
            );
            if (group != null && context.mounted) {
              Navigator.of(context).pop(group);
            }
          },
        ),
        settings: settings,
      );
    case AppRoutes.groupDetails:
      final args = settings.arguments;
      if (args is! GroupDetailsRouteArguments) {
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('群聊参数异常'))),
          settings: settings,
        );
      }
      return MaterialPageRoute<GroupDetailsResult>(
        builder: (context) => GroupDetailsPage(
          conversation: args.conversation,
          wsClient: context.read<WsClient>(),
        ),
        settings: settings,
      );
    default:
      return null;
  }
}
