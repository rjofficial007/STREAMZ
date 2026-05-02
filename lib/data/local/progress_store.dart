// data/local/progress_store.dart

import 'package:shared_preferences/shared_preferences.dart';

class ProgressStore {
  final SharedPreferences _prefs;
  final Map<String, int> _cache = {};

  ProgressStore(this._prefs) {
    _loadAll();
  }

  void _loadAll() {
    for (final key in _prefs.getKeys()) {
      if (key.startsWith('progress_') && !key.endsWith('_ts')) {
        final id = key.replaceFirst('progress_', '');
        _cache[id] = _prefs.getInt(key) ?? 0;
      }
    }
  }

  int getProgress(String id) => _cache[id] ?? 0;

  int getTimestamp(String id) => _prefs.getInt('progress_${id}_ts') ?? 0;

  Future<void> saveProgress(String id, int seconds) async {
    _cache[id] = seconds;
    final ts = DateTime.now().millisecondsSinceEpoch;
    await Future.wait([_prefs.setInt('progress_$id', seconds), _prefs.setInt('progress_${id}_ts', ts)]);
  }

  Future<void> clearProgress(String id) async {
    _cache.remove(id);
    await Future.wait([_prefs.remove('progress_$id'), _prefs.remove('progress_${id}_ts')]);
  }

  /// Returns all IDs that have saved progress, sorted by most recent
  List<String> get recentlyPlayed {
    final entries = _cache.keys.where((id) => _cache[id]! > 30).map((id) => MapEntry(id, getTimestamp(id))).toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }
}
