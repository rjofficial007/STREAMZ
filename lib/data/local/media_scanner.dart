// data/local/media_scanner.dart
// Handles scanning PhotoManager (Android/iOS/macOS), OnAudioQuery (Android),
// and raw Directory scanning (Windows/Linux/macOS).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:streamz/core/utils/file_type_utils.dart';
import 'package:streamz/core/utils/logger.dart';
import 'package:streamz/domain/models/media_item.dart';

class MediaScanner {
  final List<AssetEntity> localAssets = [];
  final Map<String, String> assetFolders = {};
  final Map<String, File> scannedFiles = {};
  List<SongModel> localSongs = [];

  final _audioQuery = OnAudioQuery();

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> scanPhotoManager({
    required bool includeVideos,
    required bool includeImages,
  }) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    logger.i('Scanning PhotoManager assets...');
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      logger.w('PhotoManager permission denied.');
      return;
    }

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
    logger.i('PhotoManager scan complete: ${localAssets.length} assets found.');
  }

  Future<void> scanAudio() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    logger.i('Scanning audio library...');
    try {
      if (await _audioQuery.checkAndRequest(retryRequest: true)) {
        localSongs = await _audioQuery.querySongs(
          sortType: SongSortType.TITLE,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        logger.i('Audio scan complete: ${localSongs.length} songs found.');
      }
    } catch (e) {
      logger.e('Audio scan error', error: e);
    }
  }

  /// Refactored to use background isolate scanning for heavy filesystem operations.
  Future<void> scanDirectory(
    String rootPath, {
    required bool includeVideos,
    required bool includeAudio,
    required bool includeImages,
    required void Function(List<MapEntry<String, String>> batch) onBatch,
  }) async {
    if (kIsWeb) return;

    logger.i('Starting background scan for: $rootPath');

    // We pass the paths to the isolate, then rebuild Files on the main thread
    // because File objects don't survive isolate transfer well if they are complex.
    final result = await compute(_scanDirectoryIsolate, {
      'rootPath': rootPath,
      'includeVideos': includeVideos,
      'includeAudio': includeAudio,
      'includeImages': includeImages,
    });

    if (result.isNotEmpty) {
      final batch = <MapEntry<String, String>>[];
      for (final path in result) {
        final id = _pathToId(path);
        final existing = scannedFiles[id];
        if (existing != null && existing.path != path) {
          // Keep the legacy ID for the last path in a collision group, as the
          // old map overwrite did, so its saved progress/history still works.
          scannedFiles
            ..remove(id)
            ..[_uniquePathId(existing.path)] = existing;
        }
        scannedFiles[id] = File(path);
        batch.add(MapEntry(id, path));
      }
      onBatch(batch);
      logger.i(
        'Directory scan complete for $rootPath: ${result.length} files found.',
      );
    }
  }

  static List<String> _scanDirectoryIsolate(Map<String, dynamic> args) {
    final rootPath = args['rootPath'] as String;
    final includeVideos = args['includeVideos'] as bool;
    final includeAudio = args['includeAudio'] as bool;
    final includeImages = args['includeImages'] as bool;

    final foundPaths = <String>[];
    final dir = Directory(rootPath);
    if (!dir.existsSync()) return [];

    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final type = FileTypeUtils.fromFilename(entity.path);
          final isTarget =
              (type == MediaFileType.video && includeVideos) ||
              (type == MediaFileType.audio && includeAudio) ||
              (type == MediaFileType.image && includeImages);

          if (isTarget) {
            foundPaths.add(entity.path);
          }
        }
      }
    } catch (_) {}
    return foundPaths;
  }

  /// Clears directory-scan results. Called before a fresh server scan so
  /// deleted files don't linger in the library.
  void clearScannedFiles() => scannedFiles.clear();

  // ── MediaItem conversion ──────────────────────────────────────────────────

  List<MediaItem> buildMediaItems({
    required bool shareVideos,
    required bool shareMusic,
    required bool shareImages,
    required int Function(String id) getProgress,
    required int Function(String id) getTimestamp,
  }) {
    final items = <MediaItem>[];

    // Directory-scanned (mounted folder) files — every non-web platform.
    // [FIX A2]: previously this branch ran only on Windows, so on
    // Android/iOS/macOS/Linux the mounted folders were scanned
    // but never surfaced in the library.
    if (!kIsWeb) {
      scannedFiles.forEach((id, file) {
        final type = FileTypeUtils.fromFilename(file.path);
        if (type == MediaFileType.video && !shareVideos) return;
        if (type == MediaFileType.audio && !shareMusic) return;
        if (type == MediaFileType.image && !shareImages) return;

        final typeStr = FileTypeUtils.toMediaType(type);
        final title = file.uri.pathSegments.last;
        final folder = _parentFolderName(file);

        items.add(
          MediaItem(
            id: id,
            title: title,
            duration: 0,
            type: typeStr,
            folder: folder,
            lastPosition: getProgress(id),
            lastPlayedTimestamp: getTimestamp(id),
          ),
        );
      });
    }

    // Photo library + audio library — non-Windows platforms.
    // (scanPhotoManager populates on android/iOS/macOS, scanAudio on
    // android/iOS; on Windows both lists are empty, so skip them there.)
    if (defaultTargetPlatform != TargetPlatform.windows) {
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
          items.add(
            MediaItem(
              id: id,
              title: s.title,
              duration: (s.duration ?? 0) ~/ 1000,
              type: 'audio',
              folder: folder,
              lastPosition: getProgress(id),
              lastPlayedTimestamp: getTimestamp(id),
            ),
          );
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

  File? fileById(String id) => scannedFiles[id];

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _pathToId(String path) {
    final encoded = hex.encode(path.codeUnits);
    return encoded.length > 32 ? encoded.substring(0, 32) : encoded;
  }

  static String _uniquePathId(String path) =>
      sha256.convert(utf8.encode(path)).toString();

  static String _parentFolderName(File file) {
    final segments = file.parent.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
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
