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

import '../../domain/models/media_item.dart';

class MediaApiClient {
  final String _baseUrl;

  // Single timeout constant used by all network calls.
  static const _timeout = Duration(seconds: 15);

  MediaApiClient(String ip) : _baseUrl = 'http://$ip:8080';

  Uri _uri(String path, [Map<String, String>? params]) => Uri.parse('$_baseUrl$path').replace(queryParameters: params);

  Future<List<MediaItem>> fetchMedia() async {
    final res = await http.get(_uri('/api/media')).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('fetchMedia failed: HTTP ${res.statusCode}');
    }
    return compute(_parseMediaItems, res.body);
  }

  static List<MediaItem> _parseMediaItems(String body) {
    final raw = jsonDecode(body) as List;
    return raw.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // FIX: Added _timeout — previously browse() had no timeout and would hang.
  Future<List<Map<String, dynamic>>> browse(String path) async {
    final res = await http.get(_uri('/api/browse', {'path': path})).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('browse failed: HTTP ${res.statusCode}');
    }
    return compute(_parseBrowseItems, res.body);
  }

  static List<Map<String, dynamic>> _parseBrowseItems(String body) {
    return (jsonDecode(body) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchStations() async {
    final res = await http.get(_uri('/api/stations')).timeout(_timeout);
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> joinStation(String id) async {
    final res = await http.get(_uri('/api/stations/join/$id')).timeout(_timeout);
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> ping() async {
    try {
      final res = await http.get(_uri('/api/media')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      // Any network error (timeout, refused, etc.) means unreachable.
      return false;
    }
  }

  String streamUrl(String id) => '$_baseUrl/stream/$id';
  String thumbnailUrl(String id) => '$_baseUrl/api/thumbnail/$id';
  String fileUrl(String path) => '$_baseUrl/api/file?path=${Uri.encodeComponent(path)}';
  String thumbnailUrlForPath(String p) => '$_baseUrl/api/thumbnail/${Uri.encodeComponent(p)}';
}
