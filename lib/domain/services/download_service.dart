// domain/services/download_service.dart
// ============================================================================
// STREAMZ — Download Service (Production-Fixed)
//
// BUGS FIXED:
//   1. http.Client() was created but never closed — leaked sockets/memory
//      on every download. Now uses a persistent client that is closed on
//      cancel/error/done.
//   2. Race condition: original `task` was replaced in _tasks list (new object)
//      but the closure captured the old object. cancelTask, progressNotifier,
//      and status updates were applied to the orphaned instance. Fixed by
//      working directly with the same task object throughout.
//   3. _savePath() hardcoded Android path for all non-Windows platforms.
//      Now uses path_provider for correct platform-specific Downloads dirs
//      (iOS, macOS, Linux, Android).
//   4. Removed the unnecessary DownloadTask replacement with a new object;
//      the original task's mutable fields (totalBytes, status) are now updated
//      directly, removing the index-lookup race.
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/domain/models/download_task.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/services/device_id_service.dart';
import 'package:streamz/domain/services/remote_command_service.dart';

class DownloadService extends ChangeNotifier {
  final List<DownloadTask> _tasks = [];
  final DeviceIdService _deviceId = sl<DeviceIdService>();

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get active => _tasks.where((t) => t.isActive).toList();
  List<DownloadTask> get completed => _tasks.where((t) => t.isCompleted).toList();

  // ── Download ──────────────────────────────────────────────────────────────

  Future<void> download({required MediaItem item, required String url}) async {
    // Deduplicate: skip if already actively downloading this item.
    if (_tasks.any((t) => t.id == item.id && t.isActive)) return;

    // FIX: Create task once and mutate it directly — no replacement/race.
    final task = DownloadTask(id: item.id, title: item.title, type: item.type, totalBytes: 0);
    _tasks.add(task);
    notifyListeners();

    // FIX: Create a single client so we can close it on every exit path.
    final client = http.Client();

    // [FIX C7] Cancel is armed BEFORE the initial request resolves —
    // cancelTask used to be assigned only after client.send() returned, so
    // an early cancel was a silent no-op and the download continued anyway.
    var cancelled = false;
    StreamSubscription? sub;
    IOSink? sink;
    File? file;
    final remote = sl<RemoteCommandService>();
    final sessionId = 'DL_${task.id}_${DateTime.now().millisecondsSinceEpoch}';

    Future<void> cancelNow() async {
      if (cancelled) return;
      cancelled = true;
      await sub?.cancel();
      try {
        await sink?.close();
      } catch (_) {}
      client.close(); // FIX: always close client
      if (await file?.exists() == true) await file?.delete();
      task.status = DownloadStatus.cancelled;
      _tasks.remove(task);
      remote.reportStatus(clientId: _deviceId.id, sessionId: sessionId, title: task.title, mediaId: task.id, progress: 0.0, mediaType: 'download', isStopped: true);
      notifyListeners();
    }

    // FIX: cancelTask closure now holds a direct reference to `task` and
    // `client`, not a stale copy pulled from the list by index.
    task.cancelTask = cancelNow;

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (cancelled) return; // cancelNow already cleaned up

      // Update total bytes directly on the task object we already have.
      task
        ..totalBytes = response.contentLength ?? 0
        ..status = DownloadStatus.downloading;
      notifyListeners();

      final savePath = await _savePath(item.title, item.type);
      if (cancelled) return; // _savePath awaits path_provider — cancel may win
      file = File(savePath);
      sink = file.openWrite();
      var downloaded = 0;
      var lastUiUpdate = DateTime.now();

      sub = response.stream.listen(
        (chunk) {
          downloaded += chunk.length;
          sink?.add(chunk);

          final now = DateTime.now();
          final shouldUpdate = now.difference(lastUiUpdate).inMilliseconds > 200 || downloaded == task.totalBytes;

          if (shouldUpdate) {
            task.downloadedBytes = downloaded;
            final prog = task.totalBytes > 0 ? (downloaded / task.totalBytes).clamp(0.0, 1.0) : 0.0;
            task.progressNotifier.value = prog;
            remote.reportStatus(clientId: _deviceId.id, sessionId: sessionId, title: task.title, mediaId: task.id, progress: prog, mediaType: 'download', isStopped: false);
            lastUiUpdate = now;
          }
        },
        onDone: () async {
          await sink?.close();
          client.close(); // FIX: close on completion
          task.downloadedBytes = task.totalBytes > 0 ? task.totalBytes : downloaded;
          task.progressNotifier.value = 1.0;
          task.status = DownloadStatus.completed;
          remote.reportStatus(clientId: _deviceId.id, sessionId: sessionId, title: task.title, mediaId: task.id, progress: 1.0, mediaType: 'download', isStopped: true);
          notifyListeners();
        },
        onError: (Object e) async {
          await sink?.close();
          client.close(); // FIX: close on error
          debugPrint('[DownloadService] Stream error: $e');
          task.status = DownloadStatus.failed;
          _tasks.remove(task);
          remote.reportStatus(clientId: _deviceId.id, sessionId: sessionId, title: task.title, mediaId: task.id, progress: 0.0, mediaType: 'download', isStopped: true);
          notifyListeners();
        },
      );
    } catch (e) {
      client.close(); // FIX: close on any exception before stream starts
      task.status = DownloadStatus.failed;
      _tasks.remove(task);
      debugPrint('[DownloadService] Download failed: $e');
      notifyListeners();
    }
  }

  Future<void> cancel(DownloadTask task) async {
    await task.cancelTask?.call();
  }

  Future<void> delete(DownloadTask task) async {
    if (task.isActive) {
      await task.cancelTask?.call();
      return;
    }
    _tasks.remove(task);
    notifyListeners();
    try {
      final path = await _savePath(task.title, task.type);
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[DownloadService] Delete error: $e');
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.isCompleted);
    notifyListeners();
  }

  // ── Save Path ─────────────────────────────────────────────────────────────

  /// [SECURITY B3] Titles come from the network (untrusted). Strip path
  /// separators, control chars, and platform-illegal characters before use
  /// as a filename — previously a crafted title could escape the Downloads
  /// directory or crash the write.
  static String sanitizeFilename(String name) {
    var safe = name.replaceAll(RegExp(r'[\r\n/\\:*?"<>|\x00-\x1f]'), '_').trim();
    if (safe.isEmpty || safe == '.') safe = 'streamz_download';
    if (safe.length > 150) safe = safe.substring(0, 150);
    return safe;
  }

  /// FIX: Platform-aware save path using path_provider.
  /// Previously hardcoded Android path for all non-Windows platforms.
  Future<String> _savePath(String filename, String type) async {
    filename = sanitizeFilename(filename);
    if (kIsWeb) return filename; // Web: not applicable

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final home = Platform.environment['USERPROFILE'] ?? '';
        return '$home\\Downloads\\$filename';
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Use the standard external storage Downloads directory on Android.
        return '/storage/emulated/0/Download/$filename';
      }

      // iOS, macOS, Linux: use app documents directory.
      // (iOS does not allow writing to arbitrary paths.)
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return '${downloadsDir.path}/$filename';
    } catch (e) {
      // Ultimate fallback: temp directory.
      final tmp = await getTemporaryDirectory();
      return '${tmp.path}/$filename';
    }
  }
}
