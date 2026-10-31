// presentation/player/player_viewmodel.dart
// ============================================================================
// STREAMZ — Player ViewModel (Production-Fixed)
//
// BUGS FIXED:
//   1. _showGestureFeedback fired notifyListeners() inside Future.delayed
//      after the ViewModel was disposed → crash.
//      Fixed by checking _isDisposed before calling notifyListeners().
//   2. _scheduleOSDHide timer fired after dispose → same crash.
//      Same guard applied.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/core/platform/player_property.dart';
import 'package:streamz/data/repositories/media_repository.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/models/remote_command.dart';
import 'package:streamz/domain/services/player_service.dart';
import 'package:streamz/domain/services/remote_command_service.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/player/playback_issue.dart';

class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel() {
    _playerService = PlayerService(repo: _repo, remote: _remote);
    videoController = VideoController(_playerService.player);

    // Wake OSD whenever any remote command arrives.
    _remoteSub = _remote.commands.listen((cmd) {
      if (_isDisposed) return;

      if (cmd.type == 'intercom') {
        _handleIntercom(cmd.value?.toString() ?? '');
      }

      wakeOSD();
    });

    _bufferSub = player.stream.buffering.listen((isBuffering) {
      if (_isDisposed) return;
      if (isBuffering) {
        // If buffering lasts more than 3s, show the recovery indicator.
        _bufferRecoveryTimer ??= Timer(const Duration(seconds: 3), () {
          _bufferRecoveryTimer = null;
          if (!_isDisposed && player.state.buffering && !_isLowFiMode) {
            _isLowFiMode = true;
            notifyListeners();
          }
        });
        _bufferTimeoutTimer ??= Timer(const Duration(seconds: 20), () {
          _bufferTimeoutTimer = null;
          if (!_isDisposed &&
              player.state.buffering &&
              _playerService.shouldBePlaying) {
            _handlePlaybackError('network timeout while buffering media');
          }
        });
        return;
      }

      _bufferRecoveryTimer?.cancel();
      _bufferRecoveryTimer = null;
      _bufferTimeoutTimer?.cancel();
      _bufferTimeoutTimer = null;
      if (_isLowFiMode) {
        _isLowFiMode = false;
        notifyListeners();
      }
    });
    _errorSub = player.stream.error.listen(_handlePlaybackError);
    _playingSub = player.stream.playing.listen(_onPlayingChanged);
    _positionSub = player.stream.position.listen(_onPositionChanged);
  }
  late final PlayerService _playerService;
  late final VideoController videoController;

  final RemoteCommandService _remote = sl<RemoteCommandService>();
  final MediaRepository _repo = sl<MediaRepository>();

  bool _showOSD = true;
  String _gestureTxt = '';
  double _gestureOpacity = 0.0;
  BoxFit _videoFit = BoxFit.contain;
  Timer? _sleepTimer;
  Timer? _bufferRecoveryTimer;
  Timer? _bufferTimeoutTimer;
  Timer? _retryTimer;
  Timer? _recoveryCheckTimer;
  Timer? _recoveryStableTimer;
  int _sleepMinutesRemaining = 0;
  double _audioDelay = 0.0;
  double _subDelay = 0.0;
  bool _isLocked = false;
  String? _intercomMessage;
  double _preIntercomVolume = 100.0;
  // [FIX D2] Duck state — re-capturing the volume on an overlapping intercom
  // used to ratchet the restored level down (20% of 20% of 100% ...).
  bool _intercomDucking = false;
  Timer? _intercomRestoreTimer;
  bool _isLowFiMode = false;
  PlaybackIssue? _playbackIssue;
  bool _isRecovering = false;
  bool _retryInFlight = false;
  int _retryAttempt = 0;
  Duration _recoveryPosition = Duration.zero;
  static const List<int> _retryDelays = [2, 4, 8, 16, 30];

  Timer? _hideTimer;
  StreamSubscription? _remoteSub;
  StreamSubscription? _bufferSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;

  // FIX: Track disposed state so async callbacks don't call notifyListeners
  // after the ViewModel has been garbage-collected.
  bool _isDisposed = false;

  bool get showOSD => _showOSD;
  String get gestureTxt => _gestureTxt;
  double get gestureOpacity => _gestureOpacity;
  BoxFit get videoFit => _videoFit;
  int get sleepMinutesRemaining => _sleepMinutesRemaining;
  double get audioDelay => _audioDelay;
  double get subDelay => _subDelay;
  bool get isLocked => _isLocked;
  bool get isLowFiMode => _isLowFiMode;
  PlaybackIssue? get playbackIssue => _playbackIssue;
  bool get isRecovering => _isRecovering;
  bool get isRetryInFlight => _retryInFlight;
  int get retryAttempt => _retryAttempt;
  Duration get recoveryPosition => _recoveryPosition;
  String? get intercomMessage => _intercomMessage;
  bool get isStopped => _playerService.isStopped;
  List<Color>? get vibeColors => _playerService.vibeColors;

  Player get player => _playerService.player;
  MediaItem? get current => _playerService.current;
  List<MediaItem> get playlist => _playerService.playlist;
  int get currentIndex => _playerService.currentIndex;
  bool get hasNext => _playerService.hasNext;
  bool get hasPrev => _playerService.hasPrev;
  String get mediaUrl => _playerService.mediaUrl;
  String get thumbUrl => _playerService.thumbUrl;

  set snapshotCallback(Future<String?> Function()? cb) =>
      _playerService.snapshotCallback = cb;

  void _handleIntercom(String msg) {
    _intercomMessage = msg;
    // [FIX D2] Capture the pre-duck volume only once per duck episode;
    // overlapping intercoms extend the restore timer instead of re-ducking
    // from the already-ducked level.
    if (!_intercomDucking) {
      _intercomDucking = true;
      _preIntercomVolume = player.state.volume;
    }
    player.setVolume(_preIntercomVolume * 0.2); // Duck to 20%
    notifyListeners();

    // Auto-clear after 10 seconds (one restore timer at a time).
    _intercomRestoreTimer?.cancel();
    _intercomRestoreTimer = Timer(const Duration(seconds: 10), () {
      _intercomRestoreTimer = null;
      _intercomDucking = false;
      if (!_isDisposed) {
        _intercomMessage = null;
        player.setVolume(_preIntercomVolume);
        notifyListeners();
      }
    });
  }

  Future<void> load({
    required List<MediaItem> items,
    required int startIndex,
    bool isPathBased = false,
    Duration? startOffset,
    bool autoPlay = true,
  }) async {
    _clearPlaybackRecovery(resetAttempts: true, notify: false);
    final clientViewModel = sl<ClientViewModel>();
    final stationId = clientViewModel.takeStationId();
    final stationRevision = clientViewModel.takeStationRevision();
    try {
      await _playerService.load(
        items: items,
        startIndex: startIndex,
        isPathBased: isPathBased,
        startOffset: startOffset,
        autoPlay: autoPlay,
        stationId: stationId,
        stationRevision: stationRevision,
      );
    } catch (error) {
      _handlePlaybackError(error.toString());
      return;
    }

    // [A3] Apply the sync role the server elected for a station join.
    // Done here (not in the screens) so every load path — initial open,
    // station switching mid-playback, remote play — gets it. A pending role
    // is consumed and dropped when a non-station playlist loads.
    final role = sl<ClientViewModel>().takeStationSyncRole();
    if (role != null && role.isNotEmpty && items.any((m) => m.isBroadcast)) {
      _playerService.setSyncMode(role);
    }

    // Log to local history if we successfully loaded an item
    if (_playerService.current != null) {
      unawaited(sl<ClientViewModel>().addToHistory(_playerService.current!));
    }

    if (!_isDisposed) {
      wakeOSD();
      notifyListeners();
    }
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> next() async {
    _clearPlaybackRecovery(resetAttempts: true, notify: false);
    await _playerService.next();
    if (!_isDisposed) {
      wakeOSD();
      notifyListeners();
    }
  }

  Future<void> prev() async {
    _clearPlaybackRecovery(resetAttempts: true, notify: false);
    await _playerService.prev();
    if (!_isDisposed) {
      wakeOSD();
      notifyListeners();
    }
  }

  Future<void> seekRelative(Duration d) async {
    await _playerService.seekRelative(d);
    if (_isDisposed) return;
    _showGestureFeedback(
      d.inSeconds > 0 ? '+${d.inSeconds}s' : '${d.inSeconds}s',
    );
    wakeOSD();
  }

  // ── Track & Rate Control (VLC Parity) ────────────────────────────────────

  Future<void> setRate(double rate) async {
    await _playerService.setRate(rate);
    _showGestureFeedback('$rate× speed');
  }

  Future<void> play() async {
    await _playerService.play();
    if (_playbackIssue?.canAutoRetry == true) {
      _isRecovering = true;
      _schedulePlaybackRetry();
    }
  }

  Future<void> pause() async {
    await _playerService.pause();
    if (_playbackIssue?.canAutoRetry == true) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _recoveryCheckTimer?.cancel();
      _recoveryCheckTimer = null;
      _isRecovering = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> togglePlayback() =>
      player.state.playing ? pause() : play();

  Future<void> retryPlayback() async {
    if (_isDisposed || current == null || _playbackIssue == null) return;
    _retryTimer?.cancel();
    _recoveryCheckTimer?.cancel();
    _recoveryStableTimer?.cancel();
    _recoveryStableTimer = null;
    _retryAttempt = 0;
    _isRecovering = true;
    if (_playbackIssue?.kind == PlaybackIssueKind.device) {
      _retryInFlight = true;
      final playback = _playerService.play();
      notifyListeners();
      try {
        await playback;
      } catch (error) {
        _handlePlaybackError(error.toString());
      } finally {
        _retryInFlight = false;
      }
      if (!_isDisposed) notifyListeners();
      if (!_isDisposed && !player.state.playing) {
        _isRecovering = false;
        notifyListeners();
      }
      return;
    }
    notifyListeners();
    await _attemptPlaybackRetry(manual: true);
  }

  void _handlePlaybackError(String message) {
    if (_isDisposed || current == null || isStopped) return;
    _playbackIssue = PlaybackIssue.fromMessage(message);
    final savedSeconds = current!.isBroadcast
        ? 0
        : _repo.getProgress(current!.id);
    final savedPosition = Duration(seconds: savedSeconds);
    final playbackPosition = player.state.position;
    _recoveryPosition = playbackPosition > savedPosition
        ? playbackPosition
        : savedPosition;
    if (_playbackIssue!.canAutoRetry && _playerService.shouldBePlaying) {
      _recoveryCheckTimer?.cancel();
      _isRecovering = true;
      if (!_retryInFlight) _schedulePlaybackRetry();
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
      _recoveryCheckTimer?.cancel();
      _recoveryCheckTimer = null;
      _isRecovering = false;
    }
    notifyListeners();
  }

  void _schedulePlaybackRetry() {
    if (_isDisposed ||
        _playbackIssue?.canAutoRetry != true ||
        !_playerService.shouldBePlaying ||
        _retryInFlight ||
        _retryTimer != null) {
      return;
    }
    final delayIndex =
        _retryAttempt.clamp(0, _retryDelays.length - 1).toInt();
    final delay = Duration(seconds: _retryDelays[delayIndex]);
    _isRecovering = true;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(_attemptPlaybackRetry());
    });
    notifyListeners();
  }

  Future<void> _attemptPlaybackRetry({bool manual = false}) async {
    if (_isDisposed || current == null || _retryInFlight) return;
    _retryInFlight = true;
    _retryAttempt++;

    final playingPosition = player.state.position;
    final savedSeconds = current!.isBroadcast ? 0 : _repo.getProgress(current!.id);
    _recoveryPosition = playingPosition > Duration(seconds: savedSeconds)
        ? playingPosition
        : Duration(seconds: savedSeconds);
    _playerService.saveCurrentProgress();
    notifyListeners();

    var retryFailed = false;
    try {
      await _playerService.retryCurrent(
        _recoveryPosition,
        resumePlayback: manual,
      );
    } catch (error) {
      _playbackIssue = PlaybackIssue.fromMessage(error.toString());
      retryFailed = true;
    } finally {
      _retryInFlight = false;
    }

    if (_isDisposed) return;
    if (_playbackIssue?.canAutoRetry == true &&
        _playerService.shouldBePlaying) {
      _recoveryCheckTimer?.cancel();
      if (retryFailed || !player.state.playing) {
        _recoveryCheckTimer = null;
        _schedulePlaybackRetry();
        return;
      }
      _recoveryCheckTimer = Timer(const Duration(seconds: 10), () {
        _recoveryCheckTimer = null;
        if (!_isDisposed && _playbackIssue?.canAutoRetry == true) {
          _schedulePlaybackRetry();
        }
      });
    } else {
      _recoveryCheckTimer?.cancel();
      _recoveryCheckTimer = null;
      _isRecovering = false;
      notifyListeners();
    }
  }

  void _onPlayingChanged(bool playing) {
    if (_isDisposed || !playing || _playbackIssue == null) return;
    _recoveryCheckTimer?.cancel();
    _recoveryCheckTimer = null;
    _recoveryStableTimer?.cancel();
    _recoveryStableTimer = Timer(const Duration(seconds: 8), () {
      if (_isDisposed || !player.state.playing) return;
      if (player.state.position > _recoveryPosition) {
        _clearPlaybackRecovery(resetAttempts: true);
      }
    });
  }

  void _onPositionChanged(Duration position) {
    if (_isDisposed ||
        !_isRecovering ||
        _playbackIssue == null ||
        !player.state.playing) {
      return;
    }
    if (position > _recoveryPosition + const Duration(seconds: 1)) {
      _clearPlaybackRecovery(resetAttempts: true);
    }
  }

  void _clearPlaybackRecovery({bool resetAttempts = false, bool notify = true}) {
    _retryTimer?.cancel();
    _retryTimer = null;
    _recoveryCheckTimer?.cancel();
    _recoveryCheckTimer = null;
    _recoveryStableTimer?.cancel();
    _recoveryStableTimer = null;
    _playbackIssue = null;
    _isRecovering = false;
    _recoveryPosition = Duration.zero;
    if (resetAttempts) _retryAttempt = 0;
    if (notify && !_isDisposed) notifyListeners();
  }

  Future<void> setAudioTrack(AudioTrack track) async {
    await _playerService.setAudioTrack(track);
    _showGestureFeedback('Audio: ${track.title ?? track.language ?? track.id}');
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await _playerService.setSubtitleTrack(track);
    final label = track.id == 'no'
        ? 'Off'
        : (track.title ?? track.language ?? track.id);
    _showGestureFeedback('Subtitles: $label');
  }

  void setVideoFit(BoxFit fit) {
    _videoFit = fit;
    final label = fit == BoxFit.contain
        ? 'Fit'
        : (fit == BoxFit.cover ? 'Fill' : 'Stretch');
    _showGestureFeedback('Aspect: $label');
    notifyListeners();
  }

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      _sleepMinutesRemaining = 0;
      _showGestureFeedback('Sleep timer off');
    } else {
      _sleepMinutesRemaining = minutes;
      _showGestureFeedback('Sleep in $minutes min');
      _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        _sleepMinutesRemaining--;
        if (_sleepMinutesRemaining <= 0) {
          _playerService.pause();
          timer.cancel();
          _showGestureFeedback('Sleep timer paused');
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void adjustVolume(double delta) {
    final current = player.state.volume;
    final next = (current + delta).clamp(0.0, 100.0);
    player.setVolume(next);
    _showGestureFeedback('Volume: ${next.toInt()}%');
  }

  void setAudioDelay(double delay) {
    _audioDelay = delay;
    _setProperty('audio-delay', delay.toStringAsFixed(3));
    _showGestureFeedback('Audio delay: ${delay.toStringAsFixed(1)} sec');
    notifyListeners();
  }

  void setSubtitleDelay(double delay) {
    _subDelay = delay;
    _setProperty('sub-delay', delay.toStringAsFixed(3));
    _showGestureFeedback('Subtitle delay: ${delay.toStringAsFixed(1)} sec');
    notifyListeners();
  }

  void toggleLock() {
    _isLocked = !_isLocked;
    _showGestureFeedback(_isLocked ? 'Controls locked' : 'Controls unlocked');
    if (!_isLocked) wakeOSD();
    notifyListeners();
  }

  void _setProperty(String key, String val) {
    unawaited(
      setPlayerProperty(player, key, val).catchError((Object error) {
        debugPrint('Error setting $key: $error');
      }),
    );
  }

  void sendRemoteCommand(RemoteCommand cmd) => _remote.send(cmd);

  // ── OSD ───────────────────────────────────────────────────────────────────

  void wakeOSD() {
    if (_isDisposed) return;
    _showOSD = true;
    notifyListeners();
    _scheduleOSDHide();
  }

  void hideOSD() {
    if (_isDisposed) return;
    _showOSD = false;
    _hideTimer?.cancel();
    notifyListeners();
  }

  void toggleOSD() {
    if (_showOSD) {
      hideOSD();
    } else {
      wakeOSD();
    }
  }

  void _scheduleOSDHide() {
    _hideTimer?.cancel();
    final item = current;
    // Auto-hide for video only. Audio and images keep the OSD visible.
    if (item == null || item.isVideo) {
      _hideTimer = Timer(const Duration(seconds: 5), () {
        // FIX: Guard before touching state after async delay.
        if (!_isDisposed) {
          _showOSD = false;
          notifyListeners();
        }
      });
    }
  }

  void _showGestureFeedback(String txt) {
    if (_isDisposed) return;
    _gestureTxt = txt;
    _gestureOpacity = 1.0;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 750), () {
      // FIX: Guard — widget may be disposed before the delay fires.
      if (!_isDisposed) {
        _gestureOpacity = 0.0;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hideTimer?.cancel();
    _sleepTimer?.cancel();
    _bufferRecoveryTimer?.cancel();
    _bufferTimeoutTimer?.cancel();
    _retryTimer?.cancel();
    _recoveryCheckTimer?.cancel();
    _recoveryStableTimer?.cancel();
    _intercomRestoreTimer?.cancel();
    _remoteSub?.cancel();
    _bufferSub?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _playerService.dispose();
    unawaited(sl<ClientViewModel>().refreshPlaybackProgress());
    super.dispose();
  }
}
