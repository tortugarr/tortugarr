import 'package:jellyfin_preference/jellyfin_preference.dart';

class RecentSearchesStore {
  static const _storageKey = 'recent_searches_v1';
  static const _maxEntries = 12;

  final PreferenceStore _store;

  RecentSearchesStore(this._store);

  List<String> get recent {
    final values = _store.getStringList(_storageKey) ?? const <String>[];
    final normalized = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        normalized.add(trimmed);
      }
      if (normalized.length >= _maxEntries) {
        break;
      }
    }

    return normalized;
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final current = recent;
    final next = <String>[trimmed];
    final seen = <String>{trimmed.toLowerCase()};

    for (final value in current) {
      final key = value.toLowerCase();
      if (seen.add(key)) {
        next.add(value);
      }
      if (next.length >= _maxEntries) {
        break;
      }
    }

    await _store.setStringList(_storageKey, next);
  }

  Future<void> clear() async {
    await _store.remove(_storageKey);
  }
}
