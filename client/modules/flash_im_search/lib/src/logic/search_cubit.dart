import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/search_history_store.dart';
import '../data/search_repository.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({
    required SearchRepository repository,
    required SearchHistoryStore historyStore,
  }) : _repository = repository,
       _historyStore = historyStore,
       super(const SearchState());

  final SearchRepository _repository;
  final SearchHistoryStore _historyStore;
  int _generation = 0;

  Future<void> loadHistory() async {
    try {
      final history = await _historyStore.load();
      if (!isClosed) emit(state.copyWith(history: history));
    } catch (_) {
      // Local history is optional and must never block remote search.
    }
  }

  Future<void> search(String value) async {
    final keyword = value.trim();
    final generation = ++_generation;
    if (keyword.isEmpty) {
      emit(
        SearchState(history: state.history, keyword: '', hasSearched: false),
      );
      return;
    }

    emit(
      SearchState(
        keyword: keyword,
        pendingSections: SearchSection.values.toSet(),
        history: state.history,
        hasSearched: true,
      ),
    );
    await Future.wait<void>([
      _loadSection(SearchSection.friends, keyword, generation),
      _loadSection(SearchSection.groups, keyword, generation),
      _loadSection(SearchSection.messages, keyword, generation),
    ]);
    if (isClosed || generation != _generation) return;
    try {
      final history = await _historyStore.save(keyword);
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(history: history));
      }
    } catch (_) {
      // Remote results remain valid when local persistence fails.
    }
  }

  Future<void> selectHistory(String keyword) => search(keyword);

  Future<void> clearHistory() async {
    try {
      await _historyStore.clear();
    } finally {
      if (!isClosed) emit(state.copyWith(history: const []));
    }
  }

  Future<void> retrySection(SearchSection section) async {
    final keyword = state.keyword;
    if (keyword.isEmpty || state.isPending(section)) return;
    final generation = _generation;
    emit(
      state.copyWith(
        pendingSections: {...state.pendingSections, section},
        failedSections: {...state.failedSections}..remove(section),
      ),
    );
    await _loadSection(section, keyword, generation);
  }

  Future<void> _loadSection(
    SearchSection section,
    String keyword,
    int generation,
  ) async {
    try {
      switch (section) {
        case SearchSection.friends:
          final friends = await _repository.searchFriends(keyword);
          _emitSectionSuccess(
            section,
            generation,
            state.copyWith(friends: friends),
          );
        case SearchSection.groups:
          final groups = await _repository.searchJoinedGroups(keyword);
          _emitSectionSuccess(
            section,
            generation,
            state.copyWith(groups: groups),
          );
        case SearchSection.messages:
          final messages = await _repository.searchMessages(keyword);
          _emitSectionSuccess(
            section,
            generation,
            state.copyWith(messageGroups: messages),
          );
      }
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          pendingSections: {...state.pendingSections}..remove(section),
          failedSections: {...state.failedSections, section},
        ),
      );
    }
  }

  void _emitSectionSuccess(
    SearchSection section,
    int generation,
    SearchState next,
  ) {
    if (isClosed || generation != _generation) return;
    emit(
      next.copyWith(
        pendingSections: {...state.pendingSections}..remove(section),
        failedSections: {...state.failedSections}..remove(section),
      ),
    );
  }
}
