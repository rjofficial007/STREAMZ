// presentation/client/client_viewmodel.dart

import 'dart:async';

import 'package:flutter/widgets.dart'; // Required for FocusManager, TraversalDirection, Actions

import '../../core/di/service_locator.dart';
import '../../data/network/media_api_client.dart';
import '../../data/network/udp_discovery.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/server_repository.dart';
import '../../domain/models/media_item.dart';
import '../../domain/services/download_service.dart';
import '../../domain/services/remote_command_service.dart';

class ClientViewModel extends ChangeNotifier {
  final MediaRepository _mediaRepo = sl<MediaRepository>();
  final ServerRepository _serverRepo = sl<ServerRepository>();
  final UdpDiscovery _discovery = sl<UdpDiscovery>();
  final RemoteCommandService remote = sl<RemoteCommandService>();

  String _targetIp = '';
  bool _isLoading = false;
  bool _isDiscovering = false;
  String? _connectionError;
  List<MediaItem> _remoteMedia = [];

  final List<String> _ipHistory = [];
  StreamSubscription? _cmdSub;

  // Anti-spam timer for remote commands
  DateTime _lastActionTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Getters ───────────────────────────────────────────────────────────────
  String get targetIp => _targetIp;
  bool get isLoading => _isLoading;
  bool get isDiscovering => _isDiscovering;
  String? get connectionError => _connectionError;
  List<MediaItem> get remoteMedia => List.unmodifiable(_remoteMedia);
  List<String> get ipHistory => List.unmodifiable(_ipHistory);
  bool get isConnected => _targetIp.isNotEmpty;

  List<MediaItem> get continueWatching => _mediaRepo.continueWatching(_remoteMedia);

  List<MediaItem> get videos => _remoteMedia.where((m) => m.isVideo).toList();
  List<MediaItem> get audio => _remoteMedia.where((m) => m.isAudio).toList();
  List<MediaItem> get images => _remoteMedia.where((m) => m.isImage).toList();

  ClientViewModel() {
    // Global Navigation Hook: Translates Remote WS Commands into Flutter UI Focus movements
    _cmdSub = remote.commands.listen((cmd) {
      if (cmd.type == 'nav') {
        final focus = FocusManager.instance.primaryFocus;
        if (focus == null) return;

        // [FIX]: Debounce execution of destructive/navigation intents.
        // We allow rapid D-Pad scrolling, but block rapid multi-tapping of 'enter' or 'back'.
        if (cmd.action == 'enter' || cmd.action == 'back') {
          final now = DateTime.now();
          if (now.difference(_lastActionTime).inMilliseconds < 450) return;
          _lastActionTime = now;
        }

        switch (cmd.action) {
          case 'up':
            focus.focusInDirection(TraversalDirection.up);
            break;
          case 'down':
            focus.focusInDirection(TraversalDirection.down);
            break;
          case 'left':
            focus.focusInDirection(TraversalDirection.left);
            break;
          case 'right':
            focus.focusInDirection(TraversalDirection.right);
            break;
          case 'enter':
            if (focus.context != null) {
              Actions.invoke(focus.context!, const ActivateIntent());
            }
            break;
          case 'back':
            if (focus.context != null) {
              Navigator.maybePop(focus.context!);
            }
            break;
        }
      }
    });
  }

  // ── Discovery ─────────────────────────────────────────────────────────────

  void startDiscovery(void Function(String ip) onFound) {
    if (_isDiscovering) return;
    _isDiscovering = true;
    notifyListeners();

    _discovery.start((ip) {
      _isDiscovering = false;
      notifyListeners();
      onFound(ip);
    });
  }

  void stopDiscovery() {
    _discovery.stop();
    _isDiscovering = false;
    notifyListeners();
  }

  // ── Connection ────────────────────────────────────────────────────────────

  Future<bool> connect(String ip) async {
    if (_isLoading) return false; // [FIX]: Prevent parallel connections on rapid taps

    if (ip.trim().isEmpty) {
      _connectionError = 'Enter an IP address';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _connectionError = null;
    notifyListeners();

    try {
      final client = MediaApiClient(ip.trim());
      final ok = await client.ping();
      if (!ok) throw Exception('Server not reachable');

      _targetIp = ip.trim();
      _mediaRepo.setClient(client);

      _remoteMedia = await _mediaRepo.fetchRemoteMedia();

      remote.connect(ip.trim());
      await _serverRepo.logAccess(ip.trim());

      if (!_ipHistory.contains(ip)) {
        _ipHistory.insert(0, ip);
        if (_ipHistory.length > 5) _ipHistory.removeLast();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _connectionError = e.toString();
      _targetIp = '';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refresh() async {
    if (_targetIp.isEmpty) return;
    try {
      _remoteMedia = await _mediaRepo.fetchRemoteMedia();
      notifyListeners();
    } catch (_) {}
  }

  void disconnect() {
    remote.disconnect();
    _mediaRepo.clearClient();
    _targetIp = '';
    _remoteMedia = [];
    notifyListeners();
  }

  /// Preview mode — uses local server as if it were remote
  void preparePreview() {
    _targetIp = '127.0.0.1';
    _mediaRepo.setClient(MediaApiClient('127.0.0.1'));
    notifyListeners();
  }

  // ── Remote Browse & Download ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> browseRemote(String path) async {
    if (_targetIp.isEmpty) return [];
    return await _mediaRepo.browseRemote(path);
  }

  void downloadMedia({required MediaItem item, required bool isPathBased}) {
    final downloadSvc = sl<DownloadService>();
    final url = isPathBased ? fileUrl(item.id) : streamUrl(item.id);
    downloadSvc.download(item: item, url: url);
  }

  // ── URL helpers ───────────────────────────────────────────────────────────
  String streamUrl(String id) => _mediaRepo.streamUrl(id);
  String thumbnailUrl(String id) => _mediaRepo.thumbnailUrl(id);
  String thumbnailUrlForPath(String p) => _mediaRepo.thumbnailUrlForPath(p);
  String fileUrl(String path) => _mediaRepo.fileUrl(path);

  @override
  void dispose() {
    _cmdSub?.cancel();
    stopDiscovery();
    super.dispose();
  }
}
