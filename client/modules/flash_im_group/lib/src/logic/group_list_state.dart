import 'package:equatable/equatable.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';

class GroupListState extends Equatable {
  GroupListState({
    List<Conversation> groups = const <Conversation>[],
    this.query = '',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  }) : groups = List<Conversation>.unmodifiable(groups);

  final List<Conversation> groups;
  final String query;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  List<Conversation> get visibleGroups {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return groups;
    }
    return groups
        .where(
          (conversation) =>
              conversation.displayName.toLowerCase().contains(keyword),
        )
        .toList(growable: false);
  }

  GroupListState copyWith({
    List<Conversation>? groups,
    String? query,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GroupListState(
      groups: groups ?? this.groups,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    groups,
    query,
    isLoading,
    isLoadingMore,
    hasMore,
    errorMessage,
  ];
}
