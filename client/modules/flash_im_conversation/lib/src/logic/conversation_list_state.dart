import 'package:equatable/equatable.dart';

import '../data/conversation.dart';

sealed class ConversationListState extends Equatable {
  const ConversationListState();

  @override
  List<Object?> get props => const [];
}

final class ConversationListInitial extends ConversationListState {
  const ConversationListInitial();
}

final class ConversationListLoading extends ConversationListState {
  const ConversationListLoading();
}

final class ConversationListLoaded extends ConversationListState {
  ConversationListLoaded({
    required this.conversations,
    required this.hasMore,
    int? totalUnread,
    this.isLoadingMore = false,
    this.loadMoreError,
  }) : totalUnread = totalUnread ?? conversations.fold<int>(0, _sumUnread);

  final List<Conversation> conversations;
  final bool hasMore;
  final int totalUnread;
  final bool isLoadingMore;
  final String? loadMoreError;

  ConversationListLoaded copyWith({
    List<Conversation>? conversations,
    bool? hasMore,
    int? totalUnread,
    bool? isLoadingMore,
    Object? loadMoreError = _unset,
  }) {
    return ConversationListLoaded(
      conversations: conversations ?? this.conversations,
      hasMore: hasMore ?? this.hasMore,
      totalUnread: totalUnread,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: identical(loadMoreError, _unset)
          ? this.loadMoreError
          : loadMoreError as String?,
    );
  }

  @override
  List<Object?> get props => [
    conversations,
    hasMore,
    totalUnread,
    isLoadingMore,
    loadMoreError,
  ];
}

final class ConversationListError extends ConversationListState {
  const ConversationListError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

const Object _unset = Object();

int _sumUnread(int total, Conversation conversation) {
  return total + conversation.unreadCount;
}
