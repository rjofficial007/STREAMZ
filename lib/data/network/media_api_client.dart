// data/network/media_api_client.dart

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/media_item.dart';

class MediaApiClient {
  final String _baseUrl;
  static const _timeout = Duration(seconds: 15);

  MediaApiClient(String ip) : _baseUrl = 'http://$ip:8080';

  Uri _uri(String path, [Map<String, String>? params]) => Uri.parse('$_baseUrl$path').replace(queryParameters: params);

  Future<List<MediaItem>> fetchMedia() async {
    final res = await http.get(_uri('/api/media')).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to load media: ${res.statusCode}');
    }
    final raw = jsonDecode(res.body) as List;
    return raw.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> browse(String path) async {
    final res = await http.get(_uri('/api/browse', {'path': path})).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Browse failed: ${res.statusCode}');
    }
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<bool> ping() async {
    try {
      final res = await http.get(_uri('/api/media')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String streamUrl(String id) => '$_baseUrl/stream/$id';
  String thumbnailUrl(String id) => '$_baseUrl/api/thumbnail/$id';
  String fileUrl(String path) => '$_baseUrl/api/file?path=${Uri.encodeComponent(path)}';
  String thumbnailUrlForPath(String p) => '$_baseUrl/api/thumbnail/${Uri.encodeComponent(p)}';
}
