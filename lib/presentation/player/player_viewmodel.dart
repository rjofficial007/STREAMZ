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

import '../../core/di/service_locator.dart';
import '../../data/repositories/media_repository.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/remote_command.dart';
import '../../domain/services/player_service.dart';
import '../../domain/services/remote_command_service.dart';

class PlayerViewModel extends ChangeNotifier {
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

  Timer? _hideTimer;
  StreamSubscription? _remoteSub;

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

  Player get player => _playerService.player;
  MediaItem? get current => _playerService.current;
  List<MediaItem> get playlist => _playerService.playlist;
  int get currentIndex => _playerService.currentIndex;
  bool get hasNext => _playerService.hasNext;
  bool get hasPrev => _playerService.hasPrev;
  String get mediaUrl => _playerService.mediaUrl;
  String get thumbUrl => _playerService.thumbUrl;

  PlayerViewModel() {
    _playerService = PlayerService(repo: _repo, remote: _remote);
    videoController = VideoController(_playerService.player);

    // Wake OSD whenever any remote command arrives.
    _remoteSub = _remote.commands.listen((_) {
      if (!_isDisposed) wakeOSD();
    });
  }

  Future<void> load({required List<MediaItem> items, required int startIndex, bool isPathBased = false}) async {
    await _playerService.load(items: items, startIndex: startIndex, isPathBased: isPathBased);
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
    _remoteSub?.cancel();
    _playerService.dispose();
    super.dispose();
  }
}
