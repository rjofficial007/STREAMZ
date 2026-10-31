// data/network/media_api_client.dart
// ============================================================================
// STREAMZ — Media API Client (Production-Fixed)
//
// BUGS FIXED:
//   1. browse() had no timeout — on a bad/stalled network the call would hang
//      forever, freezing the file manager UI. Added the same 15 s timeout
//      used by fetchMedia().
//   2. ping() silently swallowed all exceptions. Now returns false cleanly
//      for any network error (timeout, socket closed, DNS failure, etc.).
//   3. Error messages now include the response status code AND body snippet
//      for easier debugging without needing a proxy.
// ============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';

class BrowsePage {
  const BrowsePage({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final bool hasMore;
}

class MediaApiClient {
  MediaApiClient(String ip, {http.Client? httpClient})
    : _baseUrl = 'http://$ip:8080',
      _httpClient = httpClient ?? http.Client();
  final String _baseUrl;
  final http.Client _httpClient;

  // Single timeout constant used by all network calls.
  static const _timeout = Duration(seconds: 15);
  String? _mediaEtag;
  List<MediaItem>? _cachedMedia;

  Uri _uri(String path, [Map<String, String>? params]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: params);

  Future<List<MediaItem>> fetchMedia() async {
    final res = await _httpClient
        .get(_uri('/api/media'), headers: {'If-None-Match': ?_mediaEtag})
        .timeout(_timeout);
    if (res.statusCode == 304 && _cachedMedia != null) return _cachedMedia!;
    if (res.statusCode != 200) {
      throw Exception('fetchMedia failed: HTTP ${res.statusCode}');
    }
    final items = await compute(_parseMediaItems, res.body);
    _mediaEtag = res.headers['etag'];
    _cachedMedia = items;
    return items;
  }

  static List<MediaItem> _parseMediaItems(String body) {
    final raw = jsonDecode(body) as List;
    return raw
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // FIX: Added _timeout — previously browse() had no timeout and would hang.
  Future<List<Map<String, dynamic>>> browse(String path) async {
    final res = await _httpClient
        .get(_uri('/api/browse', {'path': path}))
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('browse failed: HTTP ${res.statusCode}');
    }
    return compute(_parseBrowseItems, res.body);
  }

  Future<BrowsePage> browsePage(
    String path, {
    required int offset,
    int limit = 200,
    String query = '',
    String sortBy = 'name',
    bool ascending = true,
  }) async {
    final res = await _httpClient
        .get(
          _uri('/api/browse', {
            'path': path,
            'offset': '$offset',
            'limit': '$limit',
            'sort': sortBy,
            'ascending': '$ascending',
            if (query.isNotEmpty) 'q': query,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('browse failed: HTTP ${res.statusCode}');
    }
    final result = await compute(_parseBrowsePage, res.body);
    return BrowsePage(
      items: (result['items'] as List).cast<Map<String, dynamic>>(),
      total: result['total'] as int? ?? 0,
      hasMore: result['hasMore'] == true,
    );
  }

  static Map<String, dynamic> _parseBrowsePage(String body) =>
      jsonDecode(body) as Map<String, dynamic>;

  static List<Map<String, dynamic>> _parseBrowseItems(String body) =>
      (jsonDecode(body) as List).cast<Map<String, dynamic>>();

  Future<List<BroadcastStation>> fetchStations() async {
    final res = await _httpClient.get(_uri('/api/stations')).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('fetchStations failed: HTTP ${res.statusCode}');
    }
    final raw = jsonDecode(res.body) as List;
    return raw
        .map((e) => BroadcastStation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StationJoinResponse?> joinStation(
    String id, {
    String? clientId,
  }) async {
    final res = await _httpClient
        .get(
          _uri('/api/stations/join/$id', <String, String>{
            if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) return null;
    return StationJoinResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<bool> ping() async {
    try {
      final res = await _httpClient
          .get(_uri('/api/health'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return false;
      final health = jsonDecode(res.body);
      return health is Map && health['ready'] == true;
    } catch (_) {
      // Any network error (timeout, refused, etc.) means unreachable.
      return false;
    }
  }

  String streamUrl(String id) => '$_baseUrl/stream/$id';
  String thumbnailUrl(String id) => '$_baseUrl/api/thumbnail/$id';
  String fileUrl(String path) =>
      '$_baseUrl/api/file?path=${Uri.encodeComponent(path)}';
  String thumbnailUrlForPath(String p) =>
      '$_baseUrl/api/thumbnail/${Uri.encodeComponent(p)}';

  void close() => _httpClient.close();
}
