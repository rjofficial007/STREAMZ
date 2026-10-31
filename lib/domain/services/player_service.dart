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

import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/core/utils/logger.dart';
import 'package:streamz/data/repositories/media_repository.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/models/remote_command.dart';
import 'package:streamz/domain/services/device_id_service.dart';
import 'package:streamz/domain/services/remote_command_service.dart';

class PlayerService extends ChangeNotifier {

  PlayerService({required MediaRepository repo, required RemoteCommandService remote}) : player = Player(), _repo = repo, _remote = remote {
    // [A3] Auto-advance for station (broadcast) playlists — see _onCompleted.
    _completedSub = player.stream.completed.listen(_onCompleted);
    _remote.addListener(_onRemoteConnectionChanged);
  }
  final Player player;
  final MediaRepository _repo;
  final RemoteCommandService _remote;
  final DeviceIdService _deviceId = sl<DeviceIdService>();

  List<MediaItem> _playlist = [];
  int _currentIndex = 0;
  bool _isPathBased = false;
  String _sessionId = '';
  bool _isStopped = false;
  bool _shouldBePlaying = false;
  String? _stationId;
  int _stationRevision = -1;
  List<String>? _remoteVibeColors;

  bool isSyncMaster = false;
  bool isSyncSlave = false;

  Timer? _saveTimer;
  Timer? _statusTimer;
  Timer? _syncTimer;
  DateTime? _lastSyncSentAt;
  StreamSubscription<RemoteCommand>? _cmdSub;
  StreamSubscription<bool>? _completedSub;
  bool _opening = false;
  bool _stationRestoreRunning = false;
  bool _disposed = false;
  int _statusTickCount = 0;
  int _lastSyncSequence = -1;
  int _syncLatencyTotalMs = 0;
  int _syncLatencySamples = 0;
  DateTime? _syncMetricStartedAt;

  Future<String?> Function()? snapshotCallback;

  // Simple version-based cancellation token for async operations.
  int _loadVersion = 0;

  // ── Accessors ─────────────────────────────────────────────────────────────

  // FIX: Guard against empty playlist before indexing.
  MediaItem? get current => _playlist.isEmpty ? null : _playlist[_currentIndex];

  List<MediaItem> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  bool get isPathBased => _isPathBased;
  bool get isStopped => _isStopped;
  bool get shouldBePlaying => _shouldBePlaying;
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

  Future<void> load({required List<MediaItem> items, required int startIndex, bool isPathBased = false, Duration? startOffset, bool autoPlay = true, String? stationId, int? stationRevision}) async {
    _loadVersion++;
    final currentV = _loadVersion;

    // Cancel any in-flight timers from a previous load before re-assigning.
    _saveTimer?.cancel();
    _statusTimer?.cancel();
    await _cmdSub?.cancel();

    _playlist = items;
    // FIX: clamp only if list is non-empty; otherwise default to 0.
    _currentIndex = items.isEmpty
        ? 0
        : startIndex.clamp(0, items.length - 1).toInt();
    _isPathBased = isPathBased;
    _isStopped = false;
    _shouldBePlaying = autoPlay;
    _stationId = items.any((item) => item.isBroadcast) ? stationId : null;
    _stationRevision = _stationId == null ? -1 : stationRevision ?? -1;
    _lastSyncSentAt = null;
    _syncLatencyTotalMs = 0;
    _syncLatencySamples = 0;
    _syncMetricStartedAt = null;
    // [A3] Leaving a station playlist exits sync mode — master/slave is
    // station-scoped (the CLI /sync command can re-establish ad-hoc sync).
    isSyncMaster = false;
    isSyncSlave = false;
    _sessionId = 'SESSION_${DateTime.now().millisecondsSinceEpoch}';

    await _openCurrent(startOffset: startOffset, version: currentV, autoPlay: autoPlay);

    // If a newer load arrived while we were awaiting, abort this lifecycle.
    if (currentV != _loadVersion) return;

    _startTimers();
    _listenCommands();
    notifyListeners();
  }

  Future<void> _openCurrent({Duration? startOffset, int? version, bool autoPlay = true}) async {
    // Re-entrancy guard: a sync jump and an auto-advance (or two rapid
    // next() taps) must not stack two open() calls on the same player.
    if (_opening) return;
    _opening = true;
    try {
      await _openCurrentImpl(startOffset: startOffset, version: version, autoPlay: autoPlay);
    } finally {
      _opening = false;
    }
  }

  Future<void> _openCurrentImpl({Duration? startOffset, int? version, bool autoPlay = true}) async {
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
        final canResume = saved > 5 &&
            (item.duration <= 0 || saved < item.duration * 0.95);
        if (canResume) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (targetV != _loadVersion) return;
          await player.seek(Duration(seconds: saved));
        }
      }
      
      if (targetV != _loadVersion) return;
      if (autoPlay) {
        _shouldBePlaying = true;
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

  // ── Sync Mode (station master/slave, CLI /sync) ─────────────────────────

  /// 'master' | 'slave' | anything else clears both flags.
  void setSyncMode(String mode) {
    isSyncMaster = mode == 'master';
    isSyncSlave = mode == 'slave';
    _lastSyncSentAt = null;
    notifyListeners();
  }

  /// [A3] Station playlists auto-advance (and loop) when an item finishes.
  /// Manual next()/prev() stay blocked for broadcast items — progression is
  /// owned by the station clock / sync master, and slaves are dragged along
  /// by sync_state track switches.
  void _onCompleted(bool completed) {
    if (!completed || _isStopped || _playlist.isEmpty) return;
    if (current?.isBroadcast != true) return;
    _saveCurrentProgress();
    _currentIndex = hasNext ? _currentIndex + 1 : 0;
    unawaited(_openCurrent());
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

  Future<void> play() async {
    _shouldBePlaying = true;
    await player.play();
  }

  Future<void> pause() async {
    _shouldBePlaying = false;
    await player.pause();
  }

  Future<void> togglePlayback() async {
    if (player.state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// Reopens the current stream without replacing the playlist/session.
  /// The caller supplies a position captured before the failed source resets.
  Future<void> retryCurrent(
    Duration position, {
    bool resumePlayback = false,
  }) async {
    if (_disposed || _isStopped || current == null) return;

    if (resumePlayback) _shouldBePlaying = true;
    final version = ++_loadVersion;
    for (var wait = 0; _opening && wait < 30; wait++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_disposed || version != _loadVersion) return;
    }
    if (_opening || _disposed || version != _loadVersion) return;

    final item = current!;
    final resumePosition =
        item.duration > 0 && position.inSeconds >= item.duration
        ? Duration(seconds: item.duration - 1)
        : position;
    await _openCurrent(
      startOffset: resumePosition > Duration.zero ? resumePosition : null,
      version: version,
      autoPlay: _shouldBePlaying,
    );
  }

  void saveCurrentProgress() => _saveCurrentProgress();

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
        final now = DateTime.now();
        // Station playback keeps the existing 2 Hz correction cadence. A
        // manual sync session without station subscribers needs fewer clock
        // updates, so send it at 1 Hz while keeping the same drift correction.
        final interval = _stationId == null
            ? const Duration(seconds: 1)
            : const Duration(milliseconds: 500);
        final lastSent = _lastSyncSentAt;
        if (lastSent != null && now.difference(lastSent) < interval) return;
        _lastSyncSentAt = now;

        // [A3] itemIndex/mediaId let slaves follow the master across track
        // boundaries, not just within one track.
        _remote.send(RemoteCommand('media', 'sync_state', {
          'pos': player.state.position.inMilliseconds,
          'ts': now.millisecondsSinceEpoch,
          'rate': player.state.rate,
          'itemIndex': _currentIndex,
          'mediaId': current?.id,
          if (_stationId != null) 'stationId': _stationId,
          if (_stationId != null && _stationRevision >= 0)
            'stationRevision': _stationRevision,
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
              final syncStationId = data['stationId']?.toString();
              if (data.containsKey('stationId') &&
                  syncStationId != _stationId) {
                break;
              }
              final stationRevision =
                  (data['stationRevision'] as num?)?.toInt();
              if (syncStationId != null &&
                  stationRevision != null &&
                  _stationRevision >= 0 &&
                  stationRevision != _stationRevision) {
                if (stationRevision > _stationRevision) {
                  unawaited(_restoreStationSession());
                }
                break;
              }
              final sequence = (data['sequence'] as num?)?.toInt();
              if (sequence != null && sequence <= _lastSyncSequence) break;
              if (sequence != null) _lastSyncSequence = sequence;
              final targetMs = (data['pos'] as num?)?.toInt() ?? 0;
              final senderTs = (data['ts'] as num?)?.toInt() ?? 0;
              final now = DateTime.now().millisecondsSinceEpoch;
              final measuredLatency = now - senderTs;
              final latency = measuredLatency.clamp(0, 1000).toInt();
              if (senderTs > 0) {
                _recordSyncLatency(measuredLatency.clamp(0, 60000).toInt());
              }

              final adjustedTarget = targetMs + latency;

              // [A3] Master advanced to a different track — jump there.
              final targetIndex = (data['itemIndex'] as num?)?.toInt();
              if (targetIndex != null &&
                  targetIndex != _currentIndex &&
                  targetIndex >= 0 &&
                  targetIndex < _playlist.length) {
                _saveCurrentProgress();
                _currentIndex = targetIndex;
                unawaited(_openCurrent(startOffset: Duration(milliseconds: adjustedTarget)));
              } else {
                final currentMs = player.state.position.inMilliseconds;
                if ((adjustedTarget - currentMs).abs() > 200) {
                  player.seek(Duration(milliseconds: adjustedTarget));
                }
              }

              final targetRate = (data['rate'] as num?)?.toDouble() ?? 1.0;
              if (player.state.rate != targetRate) {
                player.setRate(targetRate);
              }
            }
            break;
          case 'play':
          case 'station_resume':
            unawaited(play());
            break;
          case 'pause':
          case 'station_pause':
            unawaited(pause());
            break;
          case 'toggle_play':
            unawaited(togglePlayback());
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
              // FIX: ServerViewModel.teleport() sends the key 'position' (seconds);
              // 'progress' is still accepted for legacy payloads.
              final pos = (data['position'] ?? data['progress']) as num?;
              if (id != null) {
                // We need to fetch the full MediaItem or just try to open the URL
                // For simplicity, let's assume we can construct a MediaItem or use a simplified open.
                // In a real app, we'd query the library for the full item.
                final item = MediaItem(
                  id: id,
                  title: 'TELEPORTED',
                  duration: 0,
                  type: data['mediaType']?.toString() ?? 'video',
                  folder: 'SYS',
                );
                load(items: [item], startIndex: 0, startOffset: pos != null ? Duration(seconds: pos.toInt()) : null);
              }
            }
            break;
          case 'set_sync_mode':
            setSyncMode(cmd.value?.toString() ?? '');
            break;
        }
      }

      if (cmd.type == 'system' &&
          cmd.action == 'sync_master_available' &&
          cmd.value is Map &&
          _playlist.any((item) => item.isBroadcast)) {
        final data = cmd.value as Map;
        final stationId = data['stationId']?.toString();
        final expectedIds = (data['mediaIds'] as List?)
            ?.map((id) => id.toString())
            .toSet();
        final activeIds = _playlist.map((item) => item.id).toSet();
        if (stationId != null &&
            expectedIds != null &&
            setEquals(activeIds, expectedIds)) {
          unawaited(_claimStationSyncRole(stationId));
        }
      }

      if (cmd.type == 'system') {
        switch (cmd.action) {
          case 'ready':
            // A server process restart resets its per-process sequence counter.
            _lastSyncSequence = -1;
            if (_stationId != null && !_isStopped) {
              isSyncMaster = false;
              isSyncSlave = false;
              unawaited(_restoreStationSession());
            }
            break;
          case 'vibe_sync':
            if (cmd.value is List) {
              _remoteVibeColors = (cmd.value as List).cast<String>();
              notifyListeners();
            }
            break;
          case 'volume_up':
            player.setVolume(
              (player.state.volume + 10.0).clamp(0.0, 100.0).toDouble(),
            );
            break;
          case 'volume_down':
            player.setVolume(
              (player.state.volume - 10.0).clamp(0.0, 100.0).toDouble(),
            );
            break;
          case 'mute':
            player.setVolume(player.state.volume > 0 ? 0.0 : 100.0);
            break;
        }
      }
    });
  }

  void _recordSyncLatency(int latencyMs) {
    final now = DateTime.now();
    _syncMetricStartedAt ??= now;
    _syncLatencyTotalMs += latencyMs;
    _syncLatencySamples++;
    if (now.difference(_syncMetricStartedAt!) < const Duration(seconds: 30)) {
      return;
    }
    final averageMs = _syncLatencyTotalMs ~/ _syncLatencySamples;
    logger.i(
      '[PlaybackSync] station=${_stationId ?? 'adhoc'} '
      'samples=$_syncLatencySamples avg_latency_ms=$averageMs '
      'last_latency_ms=$latencyMs',
    );
    _syncLatencyTotalMs = 0;
    _syncLatencySamples = 0;
    _syncMetricStartedAt = now;
  }

  Future<void> _claimStationSyncRole(String stationId) async {
    await _restoreStationSession(stationId);
  }

  void _onRemoteConnectionChanged() {
    if (_remote.isConnected || (!isSyncMaster && !isSyncSlave)) return;
    isSyncMaster = false;
    isSyncSlave = false;
    _lastSyncSequence = -1;
    if (!_disposed) notifyListeners();
  }

  Future<void> _restoreStationSession([String? requestedStationId]) async {
    final stationId = requestedStationId ?? _stationId;
    if (stationId == null ||
        (requestedStationId != null && requestedStationId != _stationId) ||
        _disposed ||
        _isStopped ||
        !_remote.isConnected ||
        _stationRestoreRunning) {
      return;
    }
    _stationRestoreRunning = true;
    final version = _loadVersion;
    try {
      final response = await _repo.joinStation(stationId);
      if (response == null || !_remote.isConnected) return;
      await _applyStationSnapshot(
        response,
        stationId: stationId,
        version: version,
      );
    } catch (error) {
      debugPrint('[PlayerService] Station recovery failed: $error');
    } finally {
      _stationRestoreRunning = false;
    }
  }

  Future<void> _applyStationSnapshot(
    StationJoinResponse response, {
    required String stationId,
    required int version,
  }) async {
    if (_disposed || _isStopped || version != _loadVersion) return;
    if (response.playlist.isEmpty) return;
    for (var wait = 0; _opening && wait < 30; wait++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_disposed || _isStopped || version != _loadVersion) return;
    }
    if (_opening || !_remote.isConnected) return;
    final restoreVersion = ++_loadVersion;
    _saveCurrentProgress();
    _stationId = stationId;
    _stationRevision = response.stationRevision;
    _lastSyncSequence = -1;
    final resumePlayback = _shouldBePlaying && !response.isPaused;
    _playlist = response.playlist;
    _currentIndex = response.itemIndex
        .clamp(0, response.playlist.length - 1)
        .toInt();
    _shouldBePlaying = resumePlayback;
    await _openCurrent(
      startOffset: response.position,
      version: restoreVersion,
      autoPlay: resumePlayback,
    );
    if (_disposed || _isStopped || restoreVersion != _loadVersion) return;
    isSyncMaster = response.syncRole == 'master';
    isSyncSlave = response.syncRole == 'slave';
    _lastSyncSentAt = null;
    notifyListeners();
  }

  void _saveCurrentProgress() {
    final item = current;
    if (item == null || item.isImage || _isPathBased) return;
    final pos = player.state.position.inSeconds;
    if (pos > 0) _repo.saveProgress(item.id, pos);
  }

  Future<void> _reportStatus() async {
    final item = current;
    if (item == null || _isStopped) return;
    final dur = player.state.duration.inSeconds;
    final pos = player.state.position.inSeconds;
    final prog = dur > 0 ? (pos / dur).clamp(0.0, 1.0).toDouble() : 0.0;

    String? snapshot;
    // [FIX C13] ~10s snapshot cadence via a tick counter (the status timer
    // ticks every 2s). The old wall-clock check (`DateTime.now().second %
    // 10 == 0`) depended on the timer's wall-clock phase and could
    // silently never fire for a given timer alignment.
    _statusTickCount = (_statusTickCount + 1) % 5;
    if (_statusTickCount == 0 && snapshotCallback != null) {
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
    // Playback visualization palette with varied accents
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
    _shouldBePlaying = false;
    _saveCurrentProgress();
    _saveTimer?.cancel();
    _statusTimer?.cancel();
    _syncTimer?.cancel();
    _stationId = null;
    _stationRevision = -1;
    isSyncMaster = false;
    isSyncSlave = false;
    await _cmdSub?.cancel();

    final item = current;
    if (item != null) {
      _remote.reportStatus(clientId: _deviceId.id, sessionId: _sessionId, title: item.title, mediaId: item.id, progress: 0, mediaType: item.type, isStopped: true);
    }
    // [FIX D1] Never await a native stop() after the player is disposed —
    // dispose() must not block on an in-flight async teardown.
    if (!_disposed) {
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    // [FIX D1] _disposed makes stop() skip its awaited player.stop() —
    // otherwise stop()'s async native teardown and the player.dispose()
    // below raced (flaky native errors / crash-on-exit). stop()'s
    // synchronous prefix still runs: progress save, timer/subscription
    // cleanup, and the stopped-report.
    _disposed = true;
    _loadVersion++; // Abort any active load
    _remote.removeListener(_onRemoteConnectionChanged);
    _completedSub?.cancel();
    stop();
    player.dispose();
    super.dispose();
  }
}
