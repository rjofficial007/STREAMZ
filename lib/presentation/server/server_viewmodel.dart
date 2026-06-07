// presentation/server/server_viewmodel.dart
// ============================================================================
// STREAMZ — Server ViewModel (Production-Fixed)
//
// BUGS FIXED:
//   1. dispose() previously called stopServer() — server died when user
//      navigated away from the dashboard. Now dispose() only cancels
//      UI-facing timers. The server runs until the user explicitly taps STOP.
//   2. WakeLock is now acquired before server start and released only on
//      explicit stop — screen/WiFi sleep no longer kills the server.
//   3. Android foreground service (flutter_background) acquired on start,
//      released on stop. Includes WiFi lock via enableWifiLock: true.
//   4. Network watchdog: detects IP changes every 15 s and hot-restarts the
//      HTTP server on the new interface automatically.
//   5. AppLifecycleState forwarded from root via AppLifecycleBroadcaster —
//      re-acquires WakeLock if it was dropped during a background transition.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../main.dart' show AppLifecycleBroadcaster;
import '../../core/di/service_locator.dart';
import '../../core/utils/logger.dart';
import '../../data/local/media_scanner.dart';
import '../../data/network/http_server.dart';
import '../../data/network/udp_discovery.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/server_repository.dart';
import '../../domain/models/broadcast_station.dart';
import '../../domain/models/connection_record.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/stream_session.dart';
import '../../domain/services/lifecycle_service.dart';
import '../../domain/services/network_service.dart';

class ServerViewModel extends ChangeNotifier {
  final HttpServerService _httpServer = sl<HttpServerService>();
  final UdpBroadcaster _broadcaster = sl<UdpBroadcaster>();
  final MediaScanner _scanner = sl<MediaScanner>();
  final MediaRepository _mediaRepo = sl<MediaRepository>();
  final ServerRepository _serverRepo = sl<ServerRepository>();
  final AppLifecycleBroadcaster _lifecycleBus = sl<AppLifecycleBroadcaster>();
  final NetworkService _networkService = sl<NetworkService>();
  final LifecycleService _lifecycleService = sl<LifecycleService>();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isInitializing = false;
  String _serverIp = 'Initializing...';

  bool _useModernWebUI = true;
  bool _shareVideos = true;
  bool _shareImages = true;
  bool _shareMusic = true;
  List<String> _sharedFolders = [];
  List<BroadcastStation> _stations = [];

  final Map<String, StreamSession> _activeSessions = {};

  // UI-facing timers — cancelled on widget dispose, NOT on server stop.
  Timer? _sessionPruneTimer;
  Timer? _speedTimer;

  // Server-side timers — cancelled only when server explicitly stopped.
  Timer? _networkWatchdog;

  int _lastBytesSent = 0;
  double _currentSpeedMb = 0.0;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isRunning => _httpServer.isRunning;
  bool get isInitializing => _isInitializing;
  String get serverIp => _serverIp;
  bool get useModernWebUI => _useModernWebUI;
  bool get shareVideos => _shareVideos;
  bool get shareImages => _shareImages;
  bool get shareMusic => _shareMusic;
  List<String> get sharedFolders => List.unmodifiable(_sharedFolders);
  List<BroadcastStation> get stations => List.unmodifiable(_stations);
  List<StreamSession> get activeSessions => _activeSessions.values.toList();
  List<ConnectionRecord> get connectionHistory => _serverRepo.connectionHistory;
  int get connectedClients => _httpServer.socketCount;
  double get currentSpeedMb => _currentSpeedMb;

  // ── Constructor ───────────────────────────────────────────────────────────

  ServerViewModel() {
    _initDefaultFolders();
    _loadStations();
    _wireCallbacks();
    _httpServer.useModernWebUI = _useModernWebUI;

    // Subscribe to app lifecycle events from the root observer.
    _lifecycleBus.addListener(_onLifecycleChange);
  }

  void _loadStations() {
    final list = _serverRepo.loadStations();
    _stations = list.map((e) => BroadcastStation.fromJson(e)).toList();
    _httpServer.stations = _stations;
  }

  Future<void> _saveStations() async {
    await _serverRepo.saveStations(_stations.map((e) => e.toJson()).toList());
  }

  void _initDefaultFolders() {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null) {
        _sharedFolders = ['$home\\Videos', '$home\\Music', '$home\\Pictures'];
      } else {
        _sharedFolders = ['C:\\'];
      }
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

  // ── App Lifecycle ─────────────────────────────────────────────────────────

  void _onLifecycleChange(AppLifecycleState state) {
    if (!isRunning) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Re-confirm WakeLock in case it was dropped while going background.
        if (!_lifecycleService.wakeLockHeld) _lifecycleService.acquireKeepAlive();
        break;
      case AppLifecycleState.resumed:
        // Validate server is still running after resume.
        _checkNetworkAndRestart();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  // ── Server Lifecycle ──────────────────────────────────────────────────────

  Future<void> startServer() async {
    if (isRunning || _isInitializing) return;
    _isInitializing = true;
    notifyListeners();

    try {
      _serverIp = await _networkService.detectIp();

      // Acquire keep-alive mechanisms BEFORE the server starts.
      await _lifecycleService.acquireKeepAlive();

      // Scan media (incremental — yields to event loop every 100 items).
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
      _startUITimers();
      _startNetworkWatchdog();
    } catch (e) {
      _serverIp = 'Error: $e';
      logger.e('[ServerVM] Start error', error: e);
      // Release keep-alive mechanisms if server failed to start.
      await _lifecycleService.releaseKeepAlive();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// User-initiated stop. Releases all keep-alive mechanisms.
  Future<void> stopServer() async {
    logger.i('[ServerVM] Stopping server...');
    _speedTimer?.cancel();
    _sessionPruneTimer?.cancel();
    _networkWatchdog?.cancel();
    _networkWatchdog = null;

    try {
      // Timeout guard: don't let a hung socket block the UI forever.
      await Future.any([
        Future.wait([
          _httpServer.stop(),
          Future.microtask(() => _broadcaster.stop()),
        ]),
        Future.delayed(const Duration(seconds: 3), () => logger.w('[ServerVM] Stop timeout, forcing UI update')),
      ]);
    } catch (e) {
      logger.e('[ServerVM] Error during stop', error: e);
    }

    _activeSessions.clear();
    await _serverRepo.markAllOffline();
    await _lifecycleService.releaseKeepAlive();

    logger.i('[ServerVM] Server stopped');
    notifyListeners();
  }

  List<MediaItem> _getMediaItems() => _mediaRepo.getLocalMediaItems(shareVideos: _shareVideos, shareMusic: _shareMusic, shareImages: _shareImages);

  List<MediaItem> getLocalMediaItems({bool? shareVideos, bool? shareMusic, bool? shareImages}) {
    return _mediaRepo.getLocalMediaItems(shareVideos: shareVideos ?? _shareVideos, shareMusic: shareMusic ?? _shareMusic, shareImages: shareImages ?? _shareImages);
  }

  // ── Network Watchdog ──────────────────────────────────────────────────────

  void _startNetworkWatchdog() {
    _networkWatchdog?.cancel();
    _networkWatchdog = Timer.periodic(const Duration(seconds: 15), (_) => _checkNetworkAndRestart());
  }

  Future<void> _checkNetworkAndRestart() async {
    if (!isRunning) return;
    try {
      final currentIp = await _networkService.detectIp();
      if (currentIp != _serverIp && currentIp != 'No Network' && !currentIp.startsWith('Error')) {
        logger.i('[ServerVM] IP changed $_serverIp → $currentIp, restarting server');
        _serverIp = currentIp;

        // Hot-restart server on new interface.
        await _httpServer.stop();
        _broadcaster.stop();
        await _httpServer.start(ip: _serverIp, sharedFolders: _sharedFolders, getMediaItems: _getMediaItems);
        await _broadcaster.start(_serverIp);
        notifyListeners();
      }

      // Re-acquire background service if it was dropped.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && !_lifecycleService.backgroundActive) {
        await _lifecycleService.acquireKeepAlive();
      }

      // Re-acquire WakeLock if dropped.
      if (!_lifecycleService.wakeLockHeld) await _lifecycleService.acquireKeepAlive();
    } catch (e) {
      logger.e('[ServerVM] Network watchdog error', error: e);
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  void setUseModernWebUI(bool v) {
    _useModernWebUI = v;
    _httpServer.useModernWebUI = v;
    notifyListeners();
  }

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

  // ── Station Management ──────────────────────────────────────────────────

  void createStation(String name, List<MediaItem> items) {
    if (items.isEmpty) return;
    final station = BroadcastStation(
      id: 'STN_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      playlist: items,
      startTime: DateTime.now(),
      isActive: true,
      isPaused: false,
    );
    _stations.add(station);
    _httpServer.stations = _stations;
    _saveStations();
    notifyListeners();
  }

  void toggleStationPlayback(String stationId) {
    final idx = _stations.indexWhere((s) => s.id == stationId);
    if (idx < 0) return;

    final station = _stations[idx];
    final now = DateTime.now();

    if (station.isPaused) {
      // Resuming: Adjust startTime so that (now - newStartTime) == (pausedAt - oldStartTime)
      final pausedElapsed = station.pausedAt!.difference(station.startTime);
      final newStartTime = now.subtract(pausedElapsed);
      _stations[idx] = station.copyWith(isPaused: false, pausedAt: null, startTime: newStartTime);
      _httpServer.broadcast(jsonEncode({'type': 'media', 'action': 'station_resume'}));
    } else {
      // Pausing: Store current time as pausedAt
      _stations[idx] = station.copyWith(isPaused: true, pausedAt: now);
      _httpServer.broadcast(jsonEncode({'type': 'media', 'action': 'station_pause'}));
    }

    _httpServer.stations = _stations;
    _saveStations();
    notifyListeners();
  }

  void toggleStationActive(String stationId) {
    final idx = _stations.indexWhere((s) => s.id == stationId);
    if (idx < 0) return;

    final station = _stations[idx];
    if (station.isActive) {
      // Deactivating (Stop)
      _stations[idx] = station.copyWith(isActive: false, isPaused: false, pausedAt: null);
      _httpServer.broadcast(jsonEncode({'type': 'media', 'action': 'station_stop'}));
    } else {
      // Activating (Start) - Reset startTime to now to start from beginning
      _stations[idx] = station.copyWith(isActive: true, isPaused: false, pausedAt: null, startTime: DateTime.now());
    }

    _httpServer.stations = _stations;
    _saveStations();
    notifyListeners();
  }

  void removeStation(String id) {
    _stations.removeWhere((s) => s.id == id);
    _httpServer.stations = _stations;
    _saveStations();
    notifyListeners();
  }

  void curateStation(String vibe) {
    final all = _mediaRepo.getLocalMediaItems(shareVideos: true, shareMusic: true, shareImages: false);
    List<MediaItem> filtered = [];
    if (vibe == 'video') {
      filtered = all.where((m) => m.isVideo).toList();
    } else if (vibe == 'audio') {
      filtered = all.where((m) => m.isAudio).toList();
    } else {
      filtered = all;
    }
    if (filtered.isEmpty) return;
    filtered.shuffle();
    createStation('AUTO_${vibe.toUpperCase()}', filtered.take(15).toList());
  }

  // ── UI Timers (widget-lifetime only) ─────────────────────────────────────

  void _startUITimers() {
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

  // ── Network Detection ─────────────────────────────────────────────────────

  // Removed _detectIp as it is now handled by NetworkService.

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // CRITICAL: Do NOT call stopServer() here.
    // The HTTP server must outlive the ServerDashboard widget.
    // Only cancel UI-facing timers that should die with the widget.
    _speedTimer?.cancel();
    _sessionPruneTimer?.cancel();
    _lifecycleBus.removeListener(_onLifecycleChange);
    // _networkWatchdog intentionally NOT cancelled — keeps running.
    // _httpServer, _broadcaster, WakeLock, background service — NOT touched.
    super.dispose();
  }
}
