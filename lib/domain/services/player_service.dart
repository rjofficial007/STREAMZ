// domain/services/player_service.dart
// Thin abstraction over media_kit Player — centralises seek, progress save,
// status reporting and remote-command wiring.

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

  Timer? _saveTimer;
  Timer? _statusTimer;
  StreamSubscription<RemoteCommand>? _cmdSub;

  PlayerService({required MediaRepository repo, required RemoteCommandService remote}) : player = Player(), _repo = repo, _remote = remote;

  // ── Accessors ─────────────────────────────────────────────────────────────

  MediaItem? get current => _playlist.isEmpty ? null : _playlist[_currentIndex];

  List<MediaItem> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  bool get isPathBased => _isPathBased;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrev => _currentIndex > 0;

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

  Future<void> load({required List<MediaItem> items, required int startIndex, bool isPathBased = false}) async {
    _playlist = items;
    _currentIndex = startIndex.clamp(0, items.length - 1);
    _isPathBased = isPathBased;
    _sessionId = 'SESSION_${DateTime.now().millisecondsSinceEpoch}';

    await _openCurrent();
    _startTimers();
    _listenCommands();
    notifyListeners();
  }

  Future<void> _openCurrent() async {
    final item = current;
    if (item == null) return;
    if (!item.isImage) {
      await player.open(Media(mediaUrl));
      final saved = _repo.getProgress(item.id);
      if (saved > 5 && !_isPathBased) {
        await Future.delayed(const Duration(milliseconds: 400));
        await player.seek(Duration(seconds: saved));
      }
      await player.play();
    } else {
      await player.stop();
    }
    notifyListeners();
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  Future<void> next() async {
    if (!hasNext) return;
    _saveCurrentProgress();
    _currentIndex++;
    await _openCurrent();
  }

  Future<void> prev() async {
    final pos = player.state.position.inSeconds;
    if (!current!.isImage && pos > 5) {
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

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void _startTimers() {
    _saveTimer?.cancel();
    _statusTimer?.cancel();

    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentProgress();
    });

    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _reportStatus();
    });
  }

  void _listenCommands() {
    _cmdSub?.cancel();
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
          if (cmd.value is int) {
            seekRelative(Duration(seconds: cmd.value as int));
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
    if (item == null) return;
    final dur = player.state.duration.inSeconds;
    final pos = player.state.position.inSeconds;
    final prog = dur > 0 ? pos / dur : 0.0;
    _remote.reportStatus(clientId: 'device', sessionId: _sessionId, title: item.title, progress: prog, mediaType: item.type, isStopped: false);
  }

  Future<void> stop() async {
    _saveCurrentProgress();
    final item = current;
    if (item != null) {
      _remote.reportStatus(clientId: 'device', sessionId: _sessionId, title: item.title, progress: 0, mediaType: item.type, isStopped: true);
    }
    await player.stop();
    _saveTimer?.cancel();
    _statusTimer?.cancel();
    _cmdSub?.cancel();
  }

  @override
  void dispose() {
    stop();
    player.dispose();
    super.dispose();
  }
}
