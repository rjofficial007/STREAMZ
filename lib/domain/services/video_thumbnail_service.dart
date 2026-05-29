// domain/services/video_thumbnail_service.dart
// ============================================================================
// STREAMZ — Robust Video Thumbnail Generation Service
// Handles frame extraction with smart-seeking and cross-platform fallbacks.
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

class VideoThumbnailService {
  // Headless player used for frame extraction on platforms without robust native support (Windows).
  final _player = Player(configuration: const PlayerConfiguration(logLevel: MPVLogLevel.error));

  // Semaphore to ensure only one video is being decoded by the generator at a time.
  final _lock = _SimpleLock();

  /// Extracts a meaningful frame from the video at [path].
  /// [quality] ranges from 0-100. [maxWidth] defines the output width.
  Future<Uint8List?> generateThumbnail(String path, {int quality = 80, int maxWidth = 400}) async {
    if (!File(path).existsSync()) {
      debugPrint('[ThumbService] File does not exist: $path');
      return null;
    }

    return _lock.synchronized(() async {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        return _extractMpv(path);
      } else {
        return _extractNative(path, quality: quality, maxWidth: maxWidth);
      }
    });
  }

  /// Mobile extraction using platform-native MediaMetadataRetriever (fast).
  Future<Uint8List?> _extractNative(String path, {required int quality, required int maxWidth}) async {
    try {
      // Seek to 5 seconds to avoid black/blank frames common at the start.
      final data = await vt.VideoThumbnail.thumbnailData(video: path, imageFormat: vt.ImageFormat.JPEG, maxWidth: maxWidth, quality: quality, timeMs: 5000);

      if (data != null && data.length > 1000) return data;

      // Fallback: If 5s returned nothing or too small (e.g. video shorter than 5s), try 0s.
      return await vt.VideoThumbnail.thumbnailData(video: path, imageFormat: vt.ImageFormat.JPEG, maxWidth: maxWidth, quality: quality, timeMs: 0);
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
      if (_player.state.duration == Duration.zero) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final duration = _player.state.duration;

      // We want ~10% into the video or 5 seconds, whichever is smaller.
      final seekTarget = duration > const Duration(seconds: 10) ? const Duration(seconds: 5) : (duration > Duration.zero ? duration ~/ 2 : Duration.zero);

      if (seekTarget > Duration.zero) {
        await _player.seek(seekTarget);
        // Small delay for the decoder to push the frame
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 3. Take screenshot
      final bytes = await _player.screenshot();

      await _player.stop();
      return bytes;
    } catch (e) {
      debugPrint('[ThumbService] MPV extraction failed for $path: $e');
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
