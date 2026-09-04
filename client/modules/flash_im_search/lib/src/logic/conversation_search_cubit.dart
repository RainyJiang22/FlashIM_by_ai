import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/search_repository.dart';
import 'conversation_search_state.dart';

class ConversationSearchCubit extends Cubit<ConversationSearchState> {
  ConversationSearchCubit({
    required SearchRepository repository,
    required String conversationId,
  }) : _repository = repository,
       _conversationId = conversationId,
       super(const ConversationSearchState());

  final SearchRepository _repository;
  final String _conversationId;
  int _generation = 0;

  Future<void> search(String value) async {
    final keyword = value.trim();
    final generation = ++_generation;
    if (keyword.isEmpty) {
      emit(const ConversationSearchState());
      return;
    }
    emit(
      ConversationSearchState(
        keyword: keyword,
        isLoading: true,
        hasSearched: true,
      ),
    );
    try {
      final messages = await _repository.searchConversationMessages(
        conversationId: _conversationId,
        query: keyword,
      );
      if (!isClosed && generation == _generation) {
        emit(
          ConversationSearchState(
            keyword: keyword,
            messages: messages,
            hasSearched: true,
          ),
        );
      }
    } catch (_) {
      if (!isClosed && generation == _generation) {
        emit(
          ConversationSearchState(
            keyword: keyword,
            hasSearched: true,
            hasError: true,
          ),
        );
      }
    }
  }
}
