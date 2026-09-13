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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/data/repositories/media_repository.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/models/remote_command.dart';
import 'package:streamz/domain/services/player_service.dart';
import 'package:streamz/domain/services/remote_command_service.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';

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
      if (isBuffering && !_isLowFiMode) {
        // If we buffer for more than 3s, enter Low-Fi mode
        Timer(const Duration(seconds: 3), () {
          if (!_isDisposed && player.state.buffering) {
            _isLowFiMode = true;
            notifyListeners();
          }
        });
      } else if (!isBuffering && _isLowFiMode) {
        _isLowFiMode = false;
        notifyListeners();
      }
    });
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

  Timer? _hideTimer;
  StreamSubscription? _remoteSub;
  StreamSubscription? _bufferSub;

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

  set snapshotCallback(Future<String?> Function()? cb) => _playerService.snapshotCallback = cb;

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

  Future<void> load({required List<MediaItem> items, required int startIndex, bool isPathBased = false, Duration? startOffset, bool autoPlay = true}) async {
    await _playerService.load(items: items, startIndex: startIndex, isPathBased: isPathBased, startOffset: startOffset, autoPlay: autoPlay);

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
      unawaited(sl<MediaRepository>().addToHistory(_playerService.current!));
    }

    if (!_isDisposed) {
      wakeOSD();
      notifyListeners();
    }
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> next() async {
    await _playerService.next();
    if (!_isDisposed) {
      wakeOSD();
      notifyListeners();
    }
  }

  Future<void> prev() async {
    await _playerService.prev();
    if (!_isDisposed) {
      wakeOSD();
      notifyListeners();
    }
  }

  Future<void> seekRelative(Duration d) async {
    await _playerService.seekRelative(d);
    if (_isDisposed) return;
    _showGestureFeedback(d.inSeconds > 0 ? '+${d.inSeconds}s' : '${d.inSeconds}s');
    wakeOSD();
  }

  // ── Track & Rate Control (VLC Parity) ────────────────────────────────────

  Future<void> setRate(double rate) async {
    await _playerService.setRate(rate);
    _showGestureFeedback('${rate}x SPEED');
  }

  Future<void> setAudioTrack(AudioTrack track) async {
    await _playerService.setAudioTrack(track);
    _showGestureFeedback('AUDIO: ${track.title ?? track.language ?? track.id}');
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await _playerService.setSubtitleTrack(track);
    final label = track.id == 'no' ? 'OFF' : (track.title ?? track.language ?? track.id);
    _showGestureFeedback('SUBTITLES: $label');
  }

  void setVideoFit(BoxFit fit) {
    _videoFit = fit;
    final label = fit == BoxFit.contain ? 'FIT' : (fit == BoxFit.cover ? 'FILL' : 'STRETCH');
    _showGestureFeedback('ASPECT: $label');
    notifyListeners();
  }

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      _sleepMinutesRemaining = 0;
      _showGestureFeedback('SLEEP TIMER OFF');
    } else {
      _sleepMinutesRemaining = minutes;
      _showGestureFeedback('SLEEP IN $minutes MIN');
      _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        _sleepMinutesRemaining--;
        if (_sleepMinutesRemaining <= 0) {
          _playerService.player.pause();
          timer.cancel();
          _showGestureFeedback('SLEEP TIMER: PAUSED');
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
    _showGestureFeedback('VOLUME: ${next.toInt()}%');
  }

  void setAudioDelay(double delay) {
    _audioDelay = delay;
    _setProperty('audio-delay', delay.toStringAsFixed(3));
    _showGestureFeedback('AUDIO DELAY: ${delay.toStringAsFixed(1)}S');
    notifyListeners();
  }

  void setSubtitleDelay(double delay) {
    _subDelay = delay;
    _setProperty('sub-delay', delay.toStringAsFixed(3));
    _showGestureFeedback('SUB DELAY: ${delay.toStringAsFixed(1)}S');
    notifyListeners();
  }

  void toggleLock() {
    _isLocked = !_isLocked;
    _showGestureFeedback(_isLocked ? 'UI LOCKED' : 'UI UNLOCKED');
    if (!_isLocked) wakeOSD();
    notifyListeners();
  }

  void _setProperty(String key, String val) {
    if (kIsWeb) return; // Properties not supported on web
    try {
      if (player.platform is NativePlayer) {
        (player.platform as NativePlayer).setProperty(key, val);
      }
    } catch (e) {
      debugPrint('Error setting $key: $e');
    }
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
    _intercomRestoreTimer?.cancel();
    _remoteSub?.cancel();
    _bufferSub?.cancel();
    _playerService.dispose();
    super.dispose();
  }
}
