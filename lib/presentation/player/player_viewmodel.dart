// presentation/player/player_viewmodel.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
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

  Timer? _hideTimer;
  StreamSubscription? _remoteSub;

  bool get showOSD => _showOSD;
  String get gestureTxt => _gestureTxt;
  double get gestureOpacity => _gestureOpacity;

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

    // Listen to ALL remote commands to instantly wake the OSD
    _remoteSub = _remote.commands.listen((cmd) {
      wakeOSD();
    });
  }

  Future<void> load({required List<MediaItem> items, required int startIndex, bool isPathBased = false}) async {
    await _playerService.load(items: items, startIndex: startIndex, isPathBased: isPathBased);
    wakeOSD();
    notifyListeners();
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> next() async {
    await _playerService.next();
    wakeOSD();
    notifyListeners();
  }

  Future<void> prev() async {
    await _playerService.prev();
    wakeOSD();
    notifyListeners();
  }

  Future<void> seekRelative(Duration d) async {
    await _playerService.seekRelative(d);
    _showGestureFeedback(d.inSeconds > 0 ? '+${d.inSeconds}s' : '${d.inSeconds}s');
    wakeOSD();
  }

  void sendRemoteCommand(RemoteCommand cmd) => _remote.send(cmd);

  // ── OSD ───────────────────────────────────────────────────────────────────

  void wakeOSD() {
    _showOSD = true;
    notifyListeners();
    _scheduleOSDHide();
  }

  void hideOSD() {
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
    if (item == null || item.isVideo) {
      _hideTimer = Timer(const Duration(seconds: 5), () {
        _showOSD = false;
        notifyListeners();
      });
    }
  }

  void _showGestureFeedback(String txt) {
    _gestureTxt = txt;
    _gestureOpacity = 1.0;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 750), () {
      _gestureOpacity = 0.0;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _remoteSub?.cancel();
    _playerService.dispose();
    super.dispose();
  }
}