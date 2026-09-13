// domain/services/video_thumbnail_service.dart
// ============================================================================
// STREAMZ — Robust Video Thumbnail Generation Service
// Handles frame extraction with smart-seeking and cross-platform fallbacks.
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:media_kit/media_kit.dart';

class VideoThumbnailService {
  // Headless player used for frame extraction on platforms without robust native support (Windows).
  // ponytail (C8): created once (lazy singleton) and lives for the app's
  // lifetime — dispose() exists but has no caller, since there's no
  // app-exit hook to wire it to. Cost is bounded (one native player); a
  // half-wired teardown risks breaking thumbnail generation, so this is a
  // documented limitation rather than a speculative lifecycle change.
  final _player = Player(configuration: const PlayerConfiguration(logLevel: MPVLogLevel.error));

  // Semaphore to ensure only one video is being decoded by the generator at a time.
  final _lock = _SimpleLock();

  /// Returns the media duration in seconds, or 0 if unknown/failed.
  /// Shares the headless player and the serialization lock with thumbnail
  /// generation (one MPV instance, one decode at a time).
  Future<int> probeDuration(String path) async {
    if (!File(path).existsSync()) return 0;
    return _lock.synchronized(() async {
      try {
        await _player.open(Media(path), play: false);
        var waited = 0;
        while (_player.state.duration == Duration.zero && waited < 8) {
          await Future.delayed(const Duration(milliseconds: 250));
          waited++;
        }
        final duration = _player.state.duration;
        await _player.stop();
        return duration.inSeconds;
      } catch (e) {
        debugPrint('[ThumbService] Duration probe failed for $path: $e');
        try {
          await _player.stop();
        } catch (_) {}
        return 0;
      }
    });
  }

  /// Extracts a meaningful frame from the video at [path].
  /// [quality] ranges from 0-100. [maxWidth] defines the output width.
  Future<Uint8List?> generateThumbnail(String path, {int quality = 80, int maxWidth = 400}) async {
    if (!File(path).existsSync()) {
      debugPrint('[ThumbService] File does not exist: $path');
      return null;
    }

    return _lock.synchronized(() async {
      try {
        if (defaultTargetPlatform == TargetPlatform.windows) {
          return await _extractMpv(path);
        } else {
          return await _extractNative(path, quality: quality, maxWidth: maxWidth);
        }
      } catch (e) {
        debugPrint('[ThumbService] Unhandled error during generation for $path: $e');
        return null;
      }
    });
  }

  /// Mobile extraction using platform-native MediaMetadataRetriever (fast).
  Future<Uint8List?> _extractNative(String path, {required int quality, required int maxWidth}) async {
    try {
      debugPrint('[ThumbService] Starting native extraction for $path');

      final data = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        quality: quality,
        timeMs: 5000,
      );

      if (data.length > 1000) return data;

      // Fallback: If 5s returned nothing or too small (e.g. video shorter than 5s), try 0s.
      debugPrint('[ThumbService] 5s seek failed or empty, trying 0s for $path');
      final fallbackData = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        quality: quality,
        timeMs: 0,
      );

      if (fallbackData.length > 100) return fallbackData;

      throw Exception('Native extraction returned no data');
    } catch (e) {
      debugPrint('[ThumbService] Native extraction failed for $path: $e');
      // Final fallback to MPV if native fails on mobile (e.g. unsupported container).
      return _extractMpv(path);
    }
  }

  /// Robust extraction using libmpv (supports all media_kit formats).
  Future<Uint8List?> _extractMpv(String path) async {
    try {
      debugPrint('[ThumbService] Starting MPV extraction for $path');

      // 1. Open the file
      await _player.open(Media(path), play: false);

      // 2. Wait for duration metadata to decide where to seek
      // We wait up to 2 seconds for metadata to load
      var waitCount = 0;
      while (_player.state.duration == Duration.zero && waitCount < 4) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }

      final duration = _player.state.duration;

      // We want ~10% into the video or 5 seconds, whichever is smaller.
      final seekTarget = duration > const Duration(seconds: 10) ? const Duration(seconds: 5) : (duration > Duration.zero ? duration ~/ 2 : Duration.zero);

      if (seekTarget > Duration.zero) {
        await _player.seek(seekTarget);
        // Small delay for the decoder to push the frame
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        // Even for 0s, wait a bit for the first frame
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 3. Take screenshot
      final bytes = await _player.screenshot();

      await _player.stop();

      if (bytes == null || bytes.isEmpty) {
        debugPrint('[ThumbService] MPV extraction returned empty/null for $path');
      }

      return bytes;
    } catch (e) {
      debugPrint('[ThumbService] MPV extraction failed for $path: $e');
      try {
        await _player.stop();
      } catch (_) {}
      return null;
    }
  }

  void dispose() {
    _player.dispose();
  }
}

/// Simple non-reentrant lock to prevent concurrent heavy decoding tasks.
class _SimpleLock {
  Future<void>? _current;

  Future<T> synchronized<T>(Future<T> Function() fn) async {
    while (_current != null) {
      await _current;
    }

    final completer = Completer<void>();
    _current = completer.future;
    try {
      return await fn();
    } finally {
      _current = null;
      completer.complete();
    }
  }
}
