import 'package:equatable/equatable.dart';

import '../data/friend_request.dart';
import '../data/friend_user.dart';

class FriendState extends Equatable {
  const FriendState({
    this.friends = const [],
    this.receivedRequests = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.isSearching = false,
    this.processingRequestIds = const {},
    this.processingUserIds = const {},
    this.errorMessage,
    this.actionMessage,
  });

  final List<FriendUser> friends;
  final List<FriendRequest> receivedRequests;
  final List<FriendUser> searchResults;
  final bool isLoading;
  final bool isSearching;
  final Set<String> processingRequestIds;
  final Set<int> processingUserIds;
  final String? errorMessage;
  final String? actionMessage;

  int get pendingRequestCount => receivedRequests.length;
  bool get hasLoaded => !isLoading && errorMessage == null;

  FriendState copyWith({
    List<FriendUser>? friends,
    List<FriendRequest>? receivedRequests,
    List<FriendUser>? searchResults,
    bool? isLoading,
    bool? isSearching,
    Set<String>? processingRequestIds,
    Set<int>? processingUserIds,
    Object? errorMessage = _unset,
    Object? actionMessage = _unset,
  }) {
    return FriendState(
      friends: friends ?? this.friends,
      receivedRequests: receivedRequests ?? this.receivedRequests,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      processingRequestIds: processingRequestIds ?? this.processingRequestIds,
      processingUserIds: processingUserIds ?? this.processingUserIds,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      actionMessage: identical(actionMessage, _unset)
          ? this.actionMessage
          : actionMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    friends,
    receivedRequests,
    searchResults,
    isLoading,
    isSearching,
    processingRequestIds,
    processingUserIds,
    errorMessage,
    actionMessage,
  ];
}

const Object _unset = Object();
