import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SearchHistoryStore {
  Future<List<String>> load();

  Future<List<String>> save(String query);

  Future<void> clear();
}

class SharedPreferencesSearchHistoryStore implements SearchHistoryStore {
  const SharedPreferencesSearchHistoryStore();

  static const key = 'im_search_history_v1';
  static const maxEntries = 20;

  @override
  Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return List<String>.unmodifiable(
      preferences.getStringList(key) ?? const [],
    );
  }

  @override
  Future<List<String>> save(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return load();
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getStringList(key) ?? const <String>[];
    final next = <String>[
      normalized,
      ...existing.where((item) => item != normalized),
    ].take(maxEntries).toList(growable: false);
    await preferences.setStringList(key, next);
    return List<String>.unmodifiable(next);
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
