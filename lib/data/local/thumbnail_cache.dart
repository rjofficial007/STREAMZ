// data/local/thumbnail_cache.dart

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/logger.dart';

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
      // Clean up old entries in background
      _cleanOldEntries();
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
      return file.readAsBytes();
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
    if (_cacheDir == null) return;
    try {
      final files = _cacheDir!.listSync().whereType<File>().toList();

      // Delete files older than max age
      for (final f in files) {
        final stat = await f.stat();
        if (DateTime.now().difference(stat.modified).inDays > _maxAgedays) {
          await f.delete();
        }
      }

      // If still too large, delete oldest first
      final remaining = _cacheDir!.listSync().whereType<File>().toList();
      int totalBytes = 0;
      for (final f in remaining) {
        totalBytes += await f.length();
      }

      if (totalBytes > _maxCacheSizeMB * 1024 * 1024) {
        remaining.sort((a, b) {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return aStat.modified.compareTo(bStat.modified);
        });
        for (final f in remaining) {
          if (totalBytes <= _maxCacheSizeMB * 1024 * 1024 * 0.8) break;
          totalBytes -= await f.length();
          await f.delete();
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
