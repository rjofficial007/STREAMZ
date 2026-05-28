// domain/models/download_task.dart
// ============================================================================
// STREAMZ — Download Task (Production-Fixed)
//
// BUG FIXED:
//   totalBytes was `final` but DownloadService needed to update it once the
//   server's Content-Length response header arrived. Previously this forced
//   replacing the whole object in the list — creating a race condition.
//   Now totalBytes and status are mutable and updated in-place.
// ============================================================================

import 'package:flutter/foundation.dart';

enum DownloadStatus { queued, downloading, completed, failed, cancelled }

class DownloadTask {
  final String id;
  final String title;
  final String type;
  final bool isPathBased;

  // FIX: Made mutable — updated after Content-Length header is received.
  int totalBytes;

  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  int downloadedBytes = 0;
  DownloadStatus status = DownloadStatus.queued;

  // Closure set by DownloadService to cancel an in-progress download.
  Future<void> Function()? cancelTask;

  DownloadTask({required this.id, required this.title, required this.type, required this.totalBytes, this.isPathBased = false});

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;

  double get progressPercent => progressNotifier.value * 100;

  String get downloadedLabel {
    final mb = downloadedBytes / 1024 / 1024;
    final total = totalBytes / 1024 / 1024;
    return '${mb.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} MB';
  }
}
