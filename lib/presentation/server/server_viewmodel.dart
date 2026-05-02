// presentation/server/server_viewmodel.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../core/di/service_locator.dart';
import '../../data/local/media_scanner.dart';
import '../../data/network/http_server.dart';
import '../../data/network/udp_discovery.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/server_repository.dart';
import '../../domain/models/connection_record.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/stream_session.dart';

class ServerViewModel extends ChangeNotifier {
  final HttpServerService _httpServer = sl<HttpServerService>();
  final UdpBroadcaster _broadcaster = sl<UdpBroadcaster>();
  final MediaScanner _scanner = sl<MediaScanner>();
  final MediaRepository _mediaRepo = sl<MediaRepository>();
  final ServerRepository _serverRepo = sl<ServerRepository>();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isInitializing = false;
  String _serverIp = 'Initializing...';
  bool _shareVideos = true;
  bool _shareImages = true;
  bool _shareMusic = true;
  List<String> _sharedFolders = [];

  final Map<String, StreamSession> _activeSessions = {};
  Timer? _sessionPruneTimer;
  Timer? _speedTimer;
  int _lastBytesSent = 0;
  double _currentSpeedMb = 0.0;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isRunning => _httpServer.isRunning;
  bool get isInitializing => _isInitializing;
  String get serverIp => _serverIp;
  bool get shareVideos => _shareVideos;
  bool get shareImages => _shareImages;
  bool get shareMusic => _shareMusic;
  List<String> get sharedFolders => List.unmodifiable(_sharedFolders);
  List<StreamSession> get activeSessions => _activeSessions.values.toList();
  List<ConnectionRecord> get connectionHistory => _serverRepo.connectionHistory;
  int get connectedClients => _httpServer.socketCount;
  double get currentSpeedMb => _currentSpeedMb;

  // ── Server lifecycle ──────────────────────────────────────────────────────

  ServerViewModel() {
    _initDefaultFolders();
    _wireCallbacks();
  }

  void _initDefaultFolders() {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _sharedFolders = ['C:\\'];
    } else if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      _sharedFolders = ['/storage/emulated/0'];
    } else {
      _sharedFolders = ['/'];
    }
  }

  void _wireCallbacks() {
    _httpServer.onSessionUpdate = (sessionId, session) {
      if (session == null) {
        _activeSessions.remove(sessionId);
      } else {
        _activeSessions[sessionId] = session;
      }
      notifyListeners();
    };

    _httpServer.onConnection = (ip) async {
      final changed = await _serverRepo.logAccess(ip);
      if (changed) notifyListeners();
    };

    _httpServer.onSocketsChanged = notifyListeners;
  }

  Future<void> startServer() async {
    if (isRunning || _isInitializing) return;
    _isInitializing = true;
    notifyListeners();

    try {
      _serverIp = await _detectIp();

      // Scan media (incremental — non-blocking)
      await _scanner.scanPhotoManager(includeVideos: _shareVideos, includeImages: _shareImages);
      await _scanner.scanAudio();

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final home = Platform.environment['USERPROFILE'];
        if (home != null) {
          for (final sub in ['Videos', 'Pictures', 'Music', 'Downloads']) {
            await _scanner.scanDirectory('$home\\$sub', includeVideos: _shareVideos, includeAudio: _shareMusic, includeImages: _shareImages, onBatch: (_) => notifyListeners());
          }
        }
      }

      await _httpServer.start(ip: _serverIp, sharedFolders: _sharedFolders, getMediaItems: _getMediaItems);

      await _broadcaster.start(_serverIp);
      _startTimers();
    } catch (e) {
      _serverIp = 'Error: $e';
      debugPrint('Server start error: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    _speedTimer?.cancel();
    _sessionPruneTimer?.cancel();
    await _httpServer.stop();
    _broadcaster.stop();
    _activeSessions.clear();
    await _serverRepo.markAllOffline();
    notifyListeners();
  }

  List<MediaItem> _getMediaItems() => _mediaRepo.getLocalMediaItems(shareVideos: _shareVideos, shareMusic: _shareMusic, shareImages: _shareImages);

  // ── Settings ──────────────────────────────────────────────────────────────

  void setShareVideos(bool v) {
    _shareVideos = v;
    notifyListeners();
  }

  void setShareImages(bool v) {
    _shareImages = v;
    notifyListeners();
  }

  void setShareMusic(bool v) {
    _shareMusic = v;
    notifyListeners();
  }

  void addSharedFolder(String path) {
    if (!_sharedFolders.contains(path)) {
      _sharedFolders.add(path);
      notifyListeners();
    }
  }

  void removeSharedFolder(String path) {
    _sharedFolders.remove(path);
    notifyListeners();
  }

  void forgetConnection(ConnectionRecord record) {
    _serverRepo.forgetConnection(record.ip);
    notifyListeners();
  }

  // ── Timers ────────────────────────────────────────────────────────────────

  void _startTimers() {
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sent = _httpServer.bytesSent;
      _currentSpeedMb = (sent - _lastBytesSent) / (1024 * 1024);
      _lastBytesSent = sent;
      notifyListeners();
    });

    _sessionPruneTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _activeSessions.removeWhere((_, s) => s.isStale);
      notifyListeners();
    });
  }

  // ── Network ───────────────────────────────────────────────────────────────

  Future<String> _detectIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      String? best;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          if (addr.address.startsWith('192.168.')) return addr.address;
          best ??= addr.address;
        }
      }
      if (best != null) return best;
    } catch (_) {}

    try {
      final info = NetworkInfo();
      return await info.getWifiIP() ?? 'No Network';
    } catch (_) {
      return 'No Network';
    }
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
