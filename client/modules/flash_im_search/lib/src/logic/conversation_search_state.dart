import 'package:equatable/equatable.dart';
import 'package:flash_im_chat/flash_im_chat.dart';

class ConversationSearchState extends Equatable {
  const ConversationSearchState({
    this.keyword = '',
    this.messages = const [],
    this.isLoading = false,
    this.hasSearched = false,
    this.hasError = false,
  });

  final String keyword;
  final List<Message> messages;
  final bool isLoading;
  final bool hasSearched;
  final bool hasError;

  ConversationSearchState copyWith({
    String? keyword,
    List<Message>? messages,
    bool? isLoading,
    bool? hasSearched,
    bool? hasError,
  }) {
    return ConversationSearchState(
      keyword: keyword ?? this.keyword,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
      hasError: hasError ?? this.hasError,
    );
  }

  @override
  List<Object?> get props => [
    keyword,
    messages,
    isLoading,
    hasSearched,
    hasError,
  ];
}
