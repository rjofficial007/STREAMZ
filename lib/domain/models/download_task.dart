// domain/models/download_task.dart

import 'package:flutter/foundation.dart';

enum DownloadStatus { queued, downloading, completed, failed, cancelled }

class DownloadTask {
  final String id;
  final String title;
  final String type;
  final int totalBytes;
  final bool isPathBased;

  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  int downloadedBytes = 0;
  DownloadStatus status = DownloadStatus.queued;
  Function()? cancelTask;

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
