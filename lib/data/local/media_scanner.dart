// data/local/media_scanner.dart
// Handles scanning PhotoManager (Android/iOS/macOS), OnAudioQuery (Android),
// and raw Directory scanning (Windows/Linux/macOS).

import 'dart:io';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/utils/file_type_utils.dart';
import '../../domain/models/media_item.dart';

class MediaScanner {
  final List<AssetEntity> localAssets = [];
  final Map<String, String> assetFolders = {};
  final Map<String, File> winFiles = {};
  List<SongModel> localSongs = [];

  final _audioQuery = OnAudioQuery();

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> scanPhotoManager({required bool includeVideos, required bool includeImages}) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.macOS) return;

    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return;

    localAssets.clear();
    assetFolders.clear();

    final type = includeVideos && includeImages
        ? RequestType.common
        : includeVideos
        ? RequestType.video
        : RequestType.image;

    final paths = await PhotoManager.getAssetPathList(type: type, hasAll: true);

    for (final path in paths) {
      if (path.isAll) continue;
      final count = await path.assetCountAsync;
      if (count == 0) continue;
      final assets = await path.getAssetListRange(start: 0, end: count);
      for (final a in assets) {
        if (!assetFolders.containsKey(a.id)) {
          localAssets.add(a);
          assetFolders[a.id] = path.name;
        }
      }
    }
  }

  Future<void> scanAudio() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      if (await _audioQuery.checkAndRequest(retryRequest: true)) {
        localSongs = await _audioQuery.querySongs(sortType: SongSortType.TITLE, uriType: UriType.EXTERNAL, ignoreCase: true);
      }
    } catch (e) {
      debugPrint('Audio scan error: $e');
    }
  }

  /// Refactored to use async stream-based scanning to prevent UI thread blockage.
  Future<void> scanDirectory(
    String rootPath, {
    required bool includeVideos,
    required bool includeAudio,
    required bool includeImages,
    required void Function(List<MapEntry<String, File>> batch) onBatch,
  }) async {
    if (kIsWeb) return;

    final dir = Directory(rootPath);
    if (!await dir.exists()) return;

    final batch = <MapEntry<String, File>>[];
    int processedCount = 0;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false).handleError((_) {})) {
        if (entity is File) {
          final type = FileTypeUtils.fromFilename(entity.path);
          final isTarget = (type == MediaFileType.video && includeVideos) || (type == MediaFileType.audio && includeAudio) || (type == MediaFileType.image && includeImages);

          if (isTarget) {
            final id = _pathToId(entity.path);
            winFiles[id] = entity;
            batch.add(MapEntry(id, entity));
          }
        }

        processedCount++;
        // Batch and yield to keep UI responsive and prevent notification flooding.
        if (batch.length >= 50) {
          onBatch(List.from(batch));
          batch.clear();
          await Future.delayed(Duration.zero);
        } else if (processedCount % 200 == 0) {
          // Even if no targets found, yield occasionally to unblock event loop.
          await Future.delayed(Duration.zero);
        }
      }

      // Flush remaining.
      if (batch.isNotEmpty) {
        onBatch(batch);
      }
    } catch (e) {
      debugPrint('[MediaScanner] Directory scan error: $e');
    }
  }

  // ── MediaItem conversion ──────────────────────────────────────────────────

  List<MediaItem> buildMediaItems({
    required bool shareVideos,
    required bool shareMusic,
    required bool shareImages,
    required int Function(String id) getProgress,
    required int Function(String id) getTimestamp,
  }) {
    final items = <MediaItem>[];

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      winFiles.forEach((id, file) {
        final type = FileTypeUtils.fromFilename(file.path);
        if (type == MediaFileType.video && !shareVideos) return;
        if (type == MediaFileType.audio && !shareMusic) return;
        if (type == MediaFileType.image && !shareImages) return;

        final typeStr = FileTypeUtils.toMediaType(type);
        final title = file.uri.pathSegments.last;
        final folder = _parentFolderName(file);

        items.add(MediaItem(id: id, title: title, duration: 0, type: typeStr, folder: folder, lastPosition: getProgress(id), lastPlayedTimestamp: getTimestamp(id)));
      });
    } else {
      for (final e in localAssets) {
        final isVideo = e.type == AssetType.video;
        if (isVideo && !shareVideos) continue;
        if (!isVideo && !shareImages) continue;

        items.add(
          MediaItem(
            id: e.id,
            title: e.title ?? 'Unknown',
            duration: e.duration,
            type: isVideo ? 'video' : 'image',
            folder: assetFolders[e.id] ?? 'Unknown',
            lastPosition: getProgress(e.id),
            lastPlayedTimestamp: getTimestamp(e.id),
          ),
        );
      }

      if (shareMusic) {
        for (final s in localSongs) {
          final id = s.id.toString();
          final folder = _songFolder(s.data);
          items.add(MediaItem(id: id, title: s.title, duration: (s.duration ?? 0) ~/ 1000, type: 'audio', folder: folder, lastPosition: getProgress(id), lastPlayedTimestamp: getTimestamp(id)));
        }
      }
    }

    return items;
  }

  // ── Thumbnail resolution ──────────────────────────────────────────────────

  AssetEntity? assetById(String id) {
    try {
      return localAssets.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  SongModel? songById(String id) {
    final intId = int.tryParse(id);
    if (intId == null) return null;
    try {
      return localSongs.firstWhere((s) => s.id == intId);
    } catch (_) {
      return null;
    }
  }

  SongModel? songByPath(String path) {
    try {
      return localSongs.firstWhere((s) => s.data == path);
    } catch (_) {
      return null;
    }
  }

  File? fileById(String id) => winFiles[id];

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _pathToId(String path) => hex.encode(path.codeUnits).substring(0, 32);

  static String _parentFolderName(File file) {
    final segments = file.parent.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : 'Unknown';
  }

  static String _songFolder(String path) {
    try {
      final parts = path.split('/');
      return parts.length > 2 ? parts[parts.length - 2] : 'Music';
    } catch (_) {
      return 'Music';
    }
  }
}
