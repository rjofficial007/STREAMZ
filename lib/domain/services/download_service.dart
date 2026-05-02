// domain/services/download_service.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/di/service_locator.dart';
import '../../domain/models/download_task.dart';
import '../../domain/models/media_item.dart';
import 'remote_command_service.dart';

class DownloadService extends ChangeNotifier {
  final List<DownloadTask> _tasks = [];

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get active => _tasks.where((t) => t.isActive).toList();
  List<DownloadTask> get completed => _tasks.where((t) => t.isCompleted).toList();

  // ── Download ──────────────────────────────────────────────────────────────

  Future<void> download({required MediaItem item, required String url}) async {
    if (_tasks.any((t) => t.id == item.id && t.isActive)) return;

    final task = DownloadTask(id: item.id, title: item.title, type: item.type, totalBytes: 0, isPathBased: false);
    _tasks.add(task);
    notifyListeners();

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      final total = response.contentLength ?? 0;

      // Patch in the real total
      final idx = _tasks.indexOf(task);
      if (idx >= 0) {
        _tasks[idx] = DownloadTask(id: task.id, title: task.title, type: task.type, totalBytes: total);
        _tasks[idx].status = DownloadStatus.downloading;
      }
      notifyListeners();

      final activeTask = _tasks.firstWhere((t) => t.id == item.id && t.isActive, orElse: () => task);

      final savePath = await _savePath(item.title);
      final file = File(savePath);
      final sink = file.openWrite();
      int downloaded = 0;
      DateTime lastUpdate = DateTime.now();
      StreamSubscription? sub;

      final remote = sl<RemoteCommandService>();
      final sessionId = 'DL_${activeTask.id}';

      activeTask.cancelTask = () async {
        await sub?.cancel();
        await sink.close();
        if (await file.exists()) await file.delete();
        activeTask.status = DownloadStatus.cancelled;
        _tasks.remove(activeTask);
        remote.reportStatus(clientId: 'LOCAL_NODE', sessionId: sessionId, title: activeTask.title, progress: 0.0, mediaType: 'download', isStopped: true);
        notifyListeners();
      };

      sub = response.stream.listen(
        (chunk) {
          downloaded += chunk.length;
          sink.add(chunk);

          final now = DateTime.now();
          if (now.difference(lastUpdate).inMilliseconds > 200 || downloaded == total) {
            activeTask.downloadedBytes = downloaded;
            final prog = total > 0 ? downloaded / total : 0.0;
            activeTask.progressNotifier.value = prog;

            // Broadcast progress to server telemetry
            remote.reportStatus(clientId: 'LOCAL_NODE', sessionId: sessionId, title: activeTask.title, progress: prog, mediaType: 'download', isStopped: false);

            lastUpdate = now;
          }
        },
        onDone: () async {
          await sink.close();
          activeTask.downloadedBytes = total > 0 ? total : downloaded;
          activeTask.progressNotifier.value = 1.0;
          activeTask.status = DownloadStatus.completed;
          remote.reportStatus(clientId: 'LOCAL_NODE', sessionId: sessionId, title: activeTask.title, progress: 1.0, mediaType: 'download', isStopped: true);
          notifyListeners();
        },
        onError: (_) async {
          await sink.close();
          activeTask.status = DownloadStatus.failed;
          _tasks.remove(activeTask);
          remote.reportStatus(clientId: 'LOCAL_NODE', sessionId: sessionId, title: activeTask.title, progress: 0.0, mediaType: 'download', isStopped: true);
          notifyListeners();
        },
      );
    } catch (e) {
      task.status = DownloadStatus.failed;
      _tasks.remove(task);
      debugPrint('Download failed: $e');
      notifyListeners();
    }
  }

  Future<void> cancel(DownloadTask task) async {
    task.cancelTask?.call();
  }

  Future<void> delete(DownloadTask task) async {
    if (task.isActive) {
      task.cancelTask?.call();
      return;
    }
    _tasks.remove(task);
    notifyListeners();
    try {
      final path = await _savePath(task.title);
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.isCompleted);
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _savePath(String filename) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final home = Platform.environment['USERPROFILE'] ?? '';
      return '$home\\Downloads\\$filename';
    }
    return '/storage/emulated/0/Download/$filename';
  }
}
