// data/repositories/media_repository.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/data/local/media_scanner.dart';
import 'package:streamz/data/local/progress_store.dart';
import 'package:streamz/data/network/media_api_client.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/history_item.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/services/device_id_service.dart';

class MediaRepository {

  MediaRepository({required MediaScanner scanner, required ProgressStore progress}) : _scanner = scanner, _progress = progress;
  static const _historyKey = 'client_view_history';
  final MediaScanner _scanner;
  final ProgressStore _progress;
  MediaApiClient? _client;

  set client(MediaApiClient? client) => _client = client;
  void clearClient() => _client = null;

  // ── History ──────────────────────────────────────────────────────────────

  List<HistoryItem> getLocalHistory() {
    final list = sl<SharedPreferences>().getStringList(_historyKey) ?? [];
    return list.map((e) => HistoryItem.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addToHistory(MediaItem item) async {
    final prefs = sl<SharedPreferences>();
    final history = getLocalHistory()
      ..removeWhere((h) => h.media.id == item.id)
      ..insert(0, HistoryItem(media: item, timestamp: DateTime.now()));
    
    if (history.length > 50) history.removeLast();
    
    final list = history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_historyKey, list);
  }

  // ── Remote ────────────────────────────────────────────────────────────────

  Future<List<MediaItem>> fetchRemoteMedia() async {
    if (_client == null) throw StateError('No client connected');
    final items = await _client!.fetchMedia();
    
    // Fetch progress data from local store
    final positions = <String, int>{};
    final timestamps = <String, int>{};
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

  Future<List<BroadcastStation>> fetchStations() async {
    if (_client == null) return [];
    return _client!.fetchStations();
  }

  Future<StationJoinResponse?> joinStation(String id) async {
    if (_client == null) return null;
    // [A3] Identify ourselves so the server can elect the sync master.
    return _client!.joinStation(id, clientId: sl<DeviceIdService>().id);
  }

  // ── Local ─────────────────────────────────────────────────────────────────

  List<MediaItem> getLocalMediaItems({bool shareVideos = true, bool shareMusic = true, bool shareImages = true}) =>
      _scanner.buildMediaItems(shareVideos: shareVideos, shareMusic: shareMusic, shareImages: shareImages, getProgress: _progress.getProgress, getTimestamp: _progress.getTimestamp);

  // ── Continue Watching ─────────────────────────────────────────────────────

  List<MediaItem> continueWatching(List<MediaItem> allItems) => allItems.where((item) => item.isInProgress).toList()..sort((a, b) => b.lastPlayedTimestamp.compareTo(a.lastPlayedTimestamp));

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
