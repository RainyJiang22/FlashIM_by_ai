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
  const ConversationListLoaded({
    required this.conversations,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<Conversation> conversations;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;

  ConversationListLoaded copyWith({
    List<Conversation>? conversations,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError = _unset,
  }) {
    return ConversationListLoaded(
      conversations: conversations ?? this.conversations,
      hasMore: hasMore ?? this.hasMore,
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
