// domain/services/player_service.dart
// ============================================================================
// STREAMZ — Player Service (Production-Fixed)
//
// BUGS FIXED:
//   1. prev() crashed with null-check on `current!` when playlist was empty.
//      Added isEmpty guard before accessing current.
//   2. _showGestureFeedback (in PlayerViewModel) called notifyListeners()
//      inside Future.delayed with no disposed check. Fixed with _isDisposed.
//   3. _statusTimer and _saveTimer were not cancelled before re-starting on
//      subsequent load() calls — caused duplicate timer callbacks.
//   4. stop() is now idempotent and safe to call multiple times.
//   5. Race conditions in load() fixed with _loadVersion cancellation token.
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/di/service_locator.dart';
import '../../data/repositories/media_repository.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/remote_command.dart';
import '../services/device_id_service.dart';
import '../services/remote_command_service.dart';

class PlayerService extends ChangeNotifier {
  final Player player;
  final MediaRepository _repo;
  final RemoteCommandService _remote;
  final DeviceIdService _deviceId = sl<DeviceIdService>();

  List<MediaItem> _playlist = [];
  int _currentIndex = 0;
  bool _isPathBased = false;
  String _sessionId = '';
  bool _isStopped = false;
  List<String>? _remoteVibeColors;

  bool isSyncMaster = false;
  bool isSyncSlave = false;

  Timer? _saveTimer;
  Timer? _statusTimer;
  Timer? _syncTimer;
  StreamSubscription<RemoteCommand>? _cmdSub;

  Future<String?> Function()? snapshotCallback;

  // Simple version-based cancellation token for async operations.
  int _loadVersion = 0;

  PlayerService({required MediaRepository repo, required RemoteCommandService remote}) : player = Player(), _repo = repo, _remote = remote;

  // ── Accessors ─────────────────────────────────────────────────────────────

  // FIX: Guard against empty playlist before indexing.
  MediaItem? get current => _playlist.isEmpty ? null : _playlist[_currentIndex];

  List<MediaItem> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  bool get isPathBased => _isPathBased;
  bool get isStopped => _isStopped;
  bool get hasNext => _currentIndex < _playlist.length - 1;

  // FIX: hasPrev must also check playlist is non-empty.
  bool get hasPrev => _playlist.isNotEmpty && _currentIndex > 0;

  List<Color>? get vibeColors {
    final hexList = _remoteVibeColors ?? (current != null ? _getVibeColors(current!) : null);
    if (hexList == null) return null;
    return hexList.map((h) => Color(int.parse(h.replaceFirst('#', 'FF'), radix: 16))).toList();
  }

  String get mediaUrl {
    final item = current;
    if (item == null) return '';
    if (_isPathBased) return _repo.fileUrl(item.id);
    return _repo.streamUrl(item.id);
  }

  String get thumbUrl {
    final item = current;
    if (item == null) return '';
    if (_isPathBased) {
      if (item.isImage) return mediaUrl;
      return _repo.thumbnailUrlForPath(item.id);
    }
    return _repo.thumbnailUrl(item.id);
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load({required List<MediaItem> items, required int startIndex, bool isPathBased = false, Duration? startOffset, bool autoPlay = true}) async {
    _loadVersion++;
    final currentV = _loadVersion;

    // Cancel any in-flight timers from a previous load before re-assigning.
    _saveTimer?.cancel();
    _statusTimer?.cancel();
    _cmdSub?.cancel();

    _playlist = items;
    // FIX: clamp only if list is non-empty; otherwise default to 0.
    _currentIndex = items.isEmpty ? 0 : startIndex.clamp(0, items.length - 1);
    _isPathBased = isPathBased;
    _isStopped = false;
    _sessionId = 'SESSION_${DateTime.now().millisecondsSinceEpoch}';

    await _openCurrent(startOffset: startOffset, version: currentV, autoPlay: autoPlay);

    // If a newer load arrived while we were awaiting, abort this lifecycle.
    if (currentV != _loadVersion) return;

    _startTimers();
    _listenCommands();
    notifyListeners();
  }

  Future<void> _openCurrent({Duration? startOffset, int? version, bool autoPlay = true}) async {
    final item = current;
    if (item == null) return;
    
    final targetV = version ?? _loadVersion;
    final url = mediaUrl;

    if (!item.isImage) {
      debugPrint('[PlayerService] Opening: $url at ${startOffset?.inSeconds}s');
      // open() is async and can take time.
      await player.open(Media(url), play: false);
      if (targetV != _loadVersion) return;

      if (startOffset != null) {
        // Small delay allows the player to initialise before seeking.
        await Future.delayed(const Duration(milliseconds: 500));
        if (targetV != _loadVersion) return;
        await player.seek(startOffset);
      } else if (!_isPathBased) {
        // Restore saved position for non-path-based items.
        final saved = _repo.getProgress(item.id);
        if (saved > 5) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (targetV != _loadVersion) return;
          await player.seek(Duration(seconds: saved));
        }
      }
      
      if (targetV != _loadVersion) return;
      if (autoPlay) {
        await player.play();
      }
    } else {
      await player.stop();
    }
    notifyListeners();
  }

  // ── Playback Controls ─────────────────────────────────────────────────────

  Future<void> next() async {
    if (!hasNext || current?.isBroadcast == true) return;
    _saveCurrentProgress();
    _currentIndex++;
    await _openCurrent();
  }

  Future<void> prev() async {
    // FIX: Guard null — current can be null when playlist is empty.
    final item = current;
    if (item == null || item.isBroadcast) return;

    final pos = player.state.position.inSeconds;
    // If past the 5 s threshold, seek to start instead of going to prev track.
    if (!item.isImage && pos > 5) {
      await player.seek(Duration.zero);
      return;
    }
    if (!hasPrev) return;
    _saveCurrentProgress();
    _currentIndex--;
    await _openCurrent();
  }

  Future<void> seekRelative(Duration delta) async {
    if (current?.isImage == true || current?.isBroadcast == true) return;
    var target = player.state.position + delta;
    final max = player.state.duration;
    if (target < Duration.zero) target = Duration.zero;
    if (max.inSeconds > 0 && target > max) target = max;
    await player.seek(target);
  }

  // ── Track & Rate Control (VLC Parity) ────────────────────────────────────

  Future<void> setRate(double rate) async {
    await player.setRate(rate);
    notifyListeners();
  }

  Future<void> setAudioTrack(AudioTrack track) async {
    await player.setAudioTrack(track);
    notifyListeners();
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await player.setSubtitleTrack(track);
    notifyListeners();
  }

  Future<void> setVideoTrack(VideoTrack track) async {
    await player.setVideoTrack(track);
    notifyListeners();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void _startTimers() {
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentProgress();
    });

    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _reportStatus();
    });

    _syncTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (isSyncMaster && !_isStopped && player.state.playing) {
        _remote.send(RemoteCommand('media', 'sync_state', {
          'pos': player.state.position.inMilliseconds,
          'ts': DateTime.now().millisecondsSinceEpoch,
          'rate': player.state.rate,
        }));
      }
    });
  }

  void _listenCommands() {
    _cmdSub = _remote.commands.listen((cmd) {
      if (cmd.targetId != null && cmd.targetId != _deviceId.id) return;

      if (cmd.type == 'media') {
        switch (cmd.action) {
          case 'sync_state':
            if (isSyncSlave && cmd.value is Map) {
              final data = cmd.value as Map;
              final targetMs = data['pos'] as int;
              final senderTs = data['ts'] as int;
              final now = DateTime.now().millisecondsSinceEpoch;
              final latency = (now - senderTs).clamp(0, 1000);
              
              final adjustedTarget = targetMs + latency;
              final currentMs = player.state.position.inMilliseconds;
              
              if ((adjustedTarget - currentMs).abs() > 200) {
                player.seek(Duration(milliseconds: adjustedTarget));
              }
              
              final targetRate = (data['rate'] as num?)?.toDouble() ?? 1.0;
              if (player.state.rate != targetRate) {
                player.setRate(targetRate);
              }
            }
            break;
          case 'play':
          case 'station_resume':
            player.play();
            break;
          case 'pause':
          case 'station_pause':
            player.pause();
            break;
          case 'toggle_play':
            player.playOrPause();
            break;
          case 'stop':
          case 'station_stop':
            stop();
            break;
          case 'seek':
            if (cmd.value is num) {
              seekRelative(Duration(seconds: (cmd.value as num).toInt()));
            }
            break;
          case 'next':
            next();
            break;
          case 'prev':
            prev();
            break;
          case 'teleport':
            if (cmd.value is Map<String, dynamic>) {
              final data = cmd.value as Map<String, dynamic>;
              final id = data['mediaId']?.toString();
              final pos = data['progress'] as num?;
              if (id != null) {
                // We need to fetch the full MediaItem or just try to open the URL
                // For simplicity, let's assume we can construct a MediaItem or use a simplified open.
                // In a real app, we'd query the library for the full item.
                final item = MediaItem(id: id, title: 'TELEPORTED', duration: 0, type: 'video', folder: 'SYS');
                load(items: [item], startIndex: 0, startOffset: pos != null ? Duration(seconds: pos.toInt()) : null);
              }
            }
            break;
          case 'set_sync_mode':
            if (cmd.value == 'master') {
              isSyncMaster = true;
              isSyncSlave = false;
            } else if (cmd.value == 'slave') {
              isSyncMaster = false;
              isSyncSlave = true;
            } else {
              isSyncMaster = false;
              isSyncSlave = false;
            }
            notifyListeners();
            break;
        }
      }

      if (cmd.type == 'system') {
        switch (cmd.action) {
          case 'vibe_sync':
            if (cmd.value is List) {
              _remoteVibeColors = (cmd.value as List).cast<String>();
              notifyListeners();
            }
            break;
          case 'volume_up':
            player.setVolume((player.state.volume + 10.0).clamp(0.0, 100.0));
            break;
          case 'volume_down':
            player.setVolume((player.state.volume - 10.0).clamp(0.0, 100.0));
            break;
          case 'mute':
            player.setVolume(player.state.volume > 0 ? 0.0 : 100.0);
            break;
        }
      }
    });
  }

  void _saveCurrentProgress() {
    final item = current;
    if (item == null || item.isImage || _isPathBased) return;
    final pos = player.state.position.inSeconds;
    if (pos > 0) _repo.saveProgress(item.id, pos);
  }

  void _reportStatus() async {
    final item = current;
    if (item == null || _isStopped) return;
    final dur = player.state.duration.inSeconds;
    final pos = player.state.position.inSeconds;
    final prog = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    String? snapshot;
    // Only capture snapshot occasionally to save bandwidth/CPU
    if (DateTime.now().second % 10 == 0 && snapshotCallback != null) {
      snapshot = await snapshotCallback!();
    }

    _remote.reportStatus(
      clientId: _deviceId.id,
      sessionId: _sessionId,
      title: item.title,
      mediaId: item.id,
      progress: prog,
      position: pos,
      mediaType: item.type,
      isStopped: false,
      snapshot: snapshot,
      vibeColors: _getVibeColors(item),
    );
  }

  List<String> _getVibeColors(MediaItem item) {
    // Enhanced Brutalist Vibe Palette with more variation
    final palettes = [
      ['#FF0000', '#000000', '#FFFFFF'], // Red/Black/White
      ['#00FF00', '#000000', '#FFFFFF'], // Green/Black/White
      ['#0000FF', '#000000', '#FFFFFF'], // Blue/Black/White
      ['#FFFF00', '#000000', '#000000'], // Yellow/Black
      ['#FF00FF', '#000000', '#FFFFFF'], // Magenta/Black/White
      ['#00FFFF', '#000000', '#000000'], // Cyan/Black
      ['#FF5F1F', '#000000', '#FFFFFF'], // Neon Orange
      ['#B0FF00', '#000000', '#000000'], // Volt
    ];
    
    final hash = item.title.hashCode.abs();
    return palettes[hash % palettes.length];
  }

  Future<void> stop() async {
    if (_isStopped) return; // Idempotent.
    _isStopped = true;
    _saveCurrentProgress();
    _saveTimer?.cancel();
    _statusTimer?.cancel();
    _syncTimer?.cancel();
    _cmdSub?.cancel();

    final item = current;
    if (item != null) {
      _remote.reportStatus(clientId: _deviceId.id, sessionId: _sessionId, title: item.title, mediaId: item.id, progress: 0, mediaType: item.type, isStopped: true);
    }
    await player.stop();
  }

  @override
  void dispose() {
    _loadVersion++; // Abort any active load
    stop();
    player.dispose();
    super.dispose();
  }
}
