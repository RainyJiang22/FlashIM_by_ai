import 'package:equatable/equatable.dart';
import 'package:flash_im_friend/flash_im_friend.dart';

class CreateGroupState extends Equatable {
  CreateGroupState({
    List<FriendUser> friends = const <FriendUser>[],
    Set<int> selectedIds = const <int>{},
    Set<int> lockedIds = const <int>{},
    this.query = '',
    this.isLoading = false,
    this.isCreating = false,
    this.errorMessage,
  }) : friends = List<FriendUser>.unmodifiable(friends),
       selectedIds = Set<int>.unmodifiable(selectedIds),
       lockedIds = Set<int>.unmodifiable(lockedIds);

  final List<FriendUser> friends;
  final Set<int> selectedIds;
  final Set<int> lockedIds;
  final String query;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;

  int get selectedCount => selectedIds.length;
  bool get canCreate => selectedCount >= 2 && !isCreating;

  List<FriendUser> get visibleFriends {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return friends;
    }
    return friends
        .where((friend) {
          return friend.displayName.toLowerCase().contains(keyword) ||
              (friend.flashId?.toLowerCase().contains(keyword) ?? false) ||
              friend.accountId.toString().contains(keyword);
        })
        .toList(growable: false);
  }

  CreateGroupState copyWith({
    List<FriendUser>? friends,
    Set<int>? selectedIds,
    Set<int>? lockedIds,
    String? query,
    bool? isLoading,
    bool? isCreating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreateGroupState(
      friends: friends ?? this.friends,
      selectedIds: selectedIds ?? this.selectedIds,
      lockedIds: lockedIds ?? this.lockedIds,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    friends,
    selectedIds,
    lockedIds,
    query,
    isLoading,
    isCreating,
    errorMessage,
  ];
}
