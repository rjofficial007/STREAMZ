// data/repositories/media_repository.dart

import 'package:flutter/foundation.dart';

import '../../domain/models/media_item.dart';
import '../local/media_scanner.dart';
import '../local/progress_store.dart';
import '../network/media_api_client.dart';

class MediaRepository {
  final MediaScanner _scanner;
  final ProgressStore _progress;
  MediaApiClient? _client;

  MediaRepository({required MediaScanner scanner, required ProgressStore progress}) : _scanner = scanner, _progress = progress;

  void setClient(MediaApiClient client) => _client = client;
  void clearClient() => _client = null;

  // ── Remote ────────────────────────────────────────────────────────────────

  Future<List<MediaItem>> fetchRemoteMedia() async {
    if (_client == null) throw StateError('No client connected');
    final items = await _client!.fetchMedia();
    
    // Fetch progress data from local store
    final Map<String, int> positions = {};
    final Map<String, int> timestamps = {};
    for (final item in items) {
      positions[item.id] = _progress.getProgress(item.id);
      timestamps[item.id] = _progress.getTimestamp(item.id);
    }

    return compute(_updateMediaItemsProgress, {
      'items': items,
      'positions': positions,
      'timestamps': timestamps,
    });
  }

  static List<MediaItem> _updateMediaItemsProgress(Map<String, dynamic> data) {
    final List<MediaItem> items = data['items'];
    final Map<String, int> positions = data['positions'];
    final Map<String, int> timestamps = data['timestamps'];

    return items.map((item) => item.copyWith(
      lastPosition: positions[item.id] ?? 0,
      lastPlayedTimestamp: timestamps[item.id] ?? 0,
    )).toList();
  }

  Future<List<Map<String, dynamic>>> browseRemote(String path) async {
    if (_client == null) throw StateError('No client connected');
    return _client!.browse(path);
  }

  Future<List<Map<String, dynamic>>> fetchStations() async {
    if (_client == null) return [];
    return _client!.fetchStations();
  }

  Future<Map<String, dynamic>?> joinStation(String id) async {
    if (_client == null) return null;
    return _client!.joinStation(id);
  }

  // ── Local ─────────────────────────────────────────────────────────────────

  List<MediaItem> getLocalMediaItems({bool shareVideos = true, bool shareMusic = true, bool shareImages = true}) =>
      _scanner.buildMediaItems(shareVideos: shareVideos, shareMusic: shareMusic, shareImages: shareImages, getProgress: _progress.getProgress, getTimestamp: _progress.getTimestamp);

  // ── Continue Watching ─────────────────────────────────────────────────────

  List<MediaItem> continueWatching(List<MediaItem> allItems) {
    return allItems.where((item) => item.isInProgress).toList()..sort((a, b) => b.lastPlayedTimestamp.compareTo(a.lastPlayedTimestamp));
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  int getProgress(String id) => _progress.getProgress(id);
  int getTimestamp(String id) => _progress.getTimestamp(id);

  Future<void> saveProgress(String id, int seconds) => _progress.saveProgress(id, seconds);

  // ── URL helpers ───────────────────────────────────────────────────────────

  String streamUrl(String id) => _client?.streamUrl(id) ?? '';
  String thumbnailUrl(String id) => _client?.thumbnailUrl(id) ?? '';
  String fileUrl(String path) => _client?.fileUrl(path) ?? '';
  String thumbnailUrlForPath(String p) => _client?.thumbnailUrlForPath(p) ?? '';
}
