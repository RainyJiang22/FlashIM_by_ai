import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'create_group_state.dart';

class CreateGroupCubit extends Cubit<CreateGroupState> {
  CreateGroupCubit({
    required FriendRepository friendRepository,
    required ConversationRepository conversationRepository,
    List<FriendUser> initialMembers = const <FriendUser>[],
  }) : _friendRepository = friendRepository,
       _conversationRepository = conversationRepository,
       _initialMembers = List<FriendUser>.unmodifiable(initialMembers),
       super(
         CreateGroupState(
           friends: initialMembers,
           selectedIds: initialMembers
               .map((friend) => friend.accountId)
               .toSet(),
           lockedIds: initialMembers.map((friend) => friend.accountId).toSet(),
         ),
       );

  final FriendRepository _friendRepository;
  final ConversationRepository _conversationRepository;
  final List<FriendUser> _initialMembers;

  Future<void> loadFriends() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final loaded = await _friendRepository.getFriends();
      if (isClosed) {
        return;
      }
      final byId = <int, FriendUser>{
        for (final friend in loaded) friend.accountId: friend,
        for (final friend in _initialMembers) friend.accountId: friend,
      };
      emit(state.copyWith(friends: byId.values.toList(), isLoading: false));
    } catch (error) {
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _errorMessage(error, fallback: '好友列表加载失败'),
        ),
      );
    }
  }

  void updateQuery(String value) {
    emit(state.copyWith(query: value, clearError: true));
  }

  void toggleFriend(FriendUser friend) {
    if (state.lockedIds.contains(friend.accountId) || state.isCreating) {
      return;
    }
    final selected = Set<int>.of(state.selectedIds);
    if (!selected.remove(friend.accountId)) {
      selected.add(friend.accountId);
    }
    emit(state.copyWith(selectedIds: selected, clearError: true));
  }

  Future<Conversation?> createGroup() async {
    if (!state.canCreate) {
      return null;
    }
    emit(state.copyWith(isCreating: true, clearError: true));
    try {
      final selectedFriends = state.friends
          .where((friend) => state.selectedIds.contains(friend.accountId))
          .toList(growable: false);
      final conversation = await _conversationRepository.createGroup(
        name: _groupName(selectedFriends),
        memberIds: selectedFriends.map((friend) => friend.accountId).toList(),
      );
      if (!isClosed) {
        emit(state.copyWith(isCreating: false));
      }
      return conversation;
    } catch (error) {
      if (isClosed) {
        return null;
      }
      emit(
        state.copyWith(
          isCreating: false,
          errorMessage: _errorMessage(error, fallback: '创建群聊失败，请稍后重试'),
        ),
      );
      return null;
    }
  }
}

String _groupName(List<FriendUser> friends) {
  final names = friends.take(3).map((friend) => friend.displayName).join('、');
  final suffix = friends.length > 3 ? '等' : '';
  return String.fromCharCodes('$names$suffix'.runes.take(100));
}

String _errorMessage(Object error, {required String fallback}) {
  if (error is ConversationRequestException) {
    final message = error.serverMessage?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
  }
  return fallback;
}
