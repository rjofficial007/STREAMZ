// data/local/thumbnail_cache.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:streamz/core/utils/logger.dart';

class ThumbnailCache {
  static const _maxAgedays = 30;
  static const _maxCacheSizeMB = 512;

  Directory? _cacheDir;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final appCache = await getApplicationCacheDirectory();
      _cacheDir = Directory('${appCache.path}/streamz_thumbs');
      await _cacheDir!.create(recursive: true);
      _initialized = true;
      // Let startup finish before the cache directory is scanned.
      unawaited(Future<void>.delayed(Duration.zero, _cleanOldEntries));
    } catch (e) {
      logger.e('ThumbnailCache init error', error: e);
    }
  }

  File _cacheFile(String key) {
    final hash = md5.convert(utf8.encode(key)).toString();
    return File('${_cacheDir!.path}/$hash.jpg');
  }

  Future<Uint8List?> get(String key) async {
    if (!_initialized || kIsWeb) return null;
    try {
      final file = _cacheFile(key);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final age = DateTime.now().difference(stat.modified);
      if (age.inDays > _maxAgedays) {
        await file.delete();
        return null;
      }
      return await file.readAsBytes();
    } catch (e) {
      return null;
    }
  }

  Future<void> put(String key, Uint8List bytes) async {
    if (!_initialized || kIsWeb) return;
    try {
      await _cacheFile(key).writeAsBytes(bytes);
    } catch (e) {
      logger.e('ThumbnailCache write error', error: e);
    }
  }

  Future<void> _cleanOldEntries() async {
    final cacheDir = _cacheDir;
    if (cacheDir == null) return;
    try {
      final remaining = <MapEntry<File, FileStat>>[];
      var totalBytes = 0;
      await for (final entity in cacheDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (DateTime.now().difference(stat.modified).inDays > _maxAgedays) {
          await entity.delete();
          continue;
        }
        remaining.add(MapEntry(entity, stat));
        totalBytes += stat.size;
      }

      if (totalBytes > _maxCacheSizeMB * 1024 * 1024) {
        remaining.sort((a, b) => a.value.modified.compareTo(b.value.modified));
        for (final entry in remaining) {
          if (totalBytes <= _maxCacheSizeMB * 1024 * 1024 * 0.8) break;
          totalBytes -= entry.value.size;
          await entry.key.delete();
        }
      }
    } catch (e) {
      debugPrint('ThumbnailCache cleanup error: $e');
    }
  }

  Future<void> clear() async {
    if (_cacheDir == null) return;
    try {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create();
    } catch (e) {
      debugPrint('ThumbnailCache clear error: $e');
    }
  }
}
