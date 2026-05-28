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
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/repositories/media_repository.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/remote_command.dart';
import '../services/remote_command_service.dart';

class PlayerService extends ChangeNotifier {
  final Player player;
  final MediaRepository _repo;
  final RemoteCommandService _remote;

  List<MediaItem> _playlist = [];
  int _currentIndex = 0;
  bool _isPathBased = false;
  String _sessionId = '';
  bool _isStopped = false;

  Timer? _saveTimer;
  Timer? _statusTimer;
  StreamSubscription<RemoteCommand>? _cmdSub;

  PlayerService({required MediaRepository repo, required RemoteCommandService remote}) : player = Player(), _repo = repo, _remote = remote;

  // ── Accessors ─────────────────────────────────────────────────────────────

  // FIX: Guard against empty playlist before indexing.
  MediaItem? get current => _playlist.isEmpty ? null : _playlist[_currentIndex];

  List<MediaItem> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  bool get isPathBased => _isPathBased;
  bool get hasNext => _currentIndex < _playlist.length - 1;

  // FIX: hasPrev must also check playlist is non-empty.
  bool get hasPrev => _playlist.isNotEmpty && _currentIndex > 0;

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

  Future<void> load({required List<MediaItem> items, required int startIndex, bool isPathBased = false, Duration? startOffset}) async {
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

    await _openCurrent(startOffset: startOffset);
    _startTimers();
    _listenCommands();
    notifyListeners();
  }

  Future<void> _openCurrent({Duration? startOffset}) async {
    final item = current;
    if (item == null) return;
    if (!item.isImage) {
      await player.open(Media(mediaUrl));
      
      if (startOffset != null) {
        // Small delay allows the player to initialise before seeking.
        await Future.delayed(const Duration(milliseconds: 400));
        await player.seek(startOffset);
      } else if (!_isPathBased) {
        // Restore saved position for non-path-based items.
        final saved = _repo.getProgress(item.id);
        if (saved > 5) {
          // Small delay allows the player to initialise before seeking.
          await Future.delayed(const Duration(milliseconds: 400));
          await player.seek(Duration(seconds: saved));
        }
      }
      await player.play();
    } else {
      await player.stop();
    }
    notifyListeners();
  }

  // ── Playback Controls ─────────────────────────────────────────────────────

  Future<void> next() async {
    if (!hasNext) return;
    _saveCurrentProgress();
    _currentIndex++;
    await _openCurrent();
  }

  Future<void> prev() async {
    // FIX: Guard null — current can be null when playlist is empty.
    final item = current;
    if (item == null) return;

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
    if (current?.isImage == true) return;
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
  }

  void _listenCommands() {
    _cmdSub = _remote.commands.listen((cmd) {
      if (cmd.type != 'media') return;
      switch (cmd.action) {
        case 'play':
          player.play();
          break;
        case 'pause':
          player.pause();
          break;
        case 'toggle_play':
          player.playOrPause();
          break;
        case 'stop':
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
      }
    });
  }

  void _saveCurrentProgress() {
    final item = current;
    if (item == null || item.isImage || _isPathBased) return;
    final pos = player.state.position.inSeconds;
    if (pos > 0) _repo.saveProgress(item.id, pos);
  }

  void _reportStatus() {
    final item = current;
    if (item == null || _isStopped) return;
    final dur = player.state.duration.inSeconds;
    final pos = player.state.position.inSeconds;
    final prog = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    _remote.reportStatus(clientId: 'device', sessionId: _sessionId, title: item.title, progress: prog, mediaType: item.type, isStopped: false);
  }

  Future<void> stop() async {
    if (_isStopped) return; // Idempotent.
    _isStopped = true;
    _saveCurrentProgress();
    _saveTimer?.cancel();
    _statusTimer?.cancel();
    _cmdSub?.cancel();

    final item = current;
    if (item != null) {
      _remote.reportStatus(clientId: 'device', sessionId: _sessionId, title: item.title, progress: 0, mediaType: item.type, isStopped: true);
    }
    await player.stop();
  }

  @override
  void dispose() {
    stop();
    player.dispose();
    super.dispose();
  }
}
