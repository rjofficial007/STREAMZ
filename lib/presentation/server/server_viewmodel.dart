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
import 'package:flutter_background/flutter_background.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../main.dart' show AppLifecycleBroadcaster;
import '../../core/di/service_locator.dart';
import '../../data/local/media_scanner.dart';
import '../../data/network/http_server.dart';
import '../../data/network/udp_discovery.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/server_repository.dart';
import '../../domain/models/broadcast_station.dart';
import '../../domain/models/connection_record.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/stream_session.dart';

class ServerViewModel extends ChangeNotifier {
  final HttpServerService _httpServer = sl<HttpServerService>();
  final UdpBroadcaster _broadcaster = sl<UdpBroadcaster>();
  final MediaScanner _scanner = sl<MediaScanner>();
  final MediaRepository _mediaRepo = sl<MediaRepository>();
  final ServerRepository _serverRepo = sl<ServerRepository>();
  final AppLifecycleBroadcaster _lifecycleBus = sl<AppLifecycleBroadcaster>();

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
  bool _wakeLockHeld = false;
  bool _backgroundActive = false;

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
        if (!_wakeLockHeld) _acquireWakeLock();
        break;
      case AppLifecycleState.resumed:
        // Validate server is still running after resume.
        _checkNetworkAndRestart();
        break;
      case AppLifecycleState.detached:
        // App process detaching — do NOT stop server; OS will decide.
        break;
    }
  }

  // ── Server Lifecycle ──────────────────────────────────────────────────────

  Future<void> startServer() async {
    if (isRunning || _isInitializing) return;
    _isInitializing = true;
    notifyListeners();

    try {
      _serverIp = await _detectIp();

      // Acquire keep-alive mechanisms BEFORE the server starts.
      await _acquireWakeLock();
      await _acquireBackgroundService();

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
      debugPrint('[ServerVM] Start error: $e');
      // Release keep-alive mechanisms if server failed to start.
      await _releaseWakeLock();
      await _releaseBackgroundService();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// User-initiated stop. Releases all keep-alive mechanisms.
  Future<void> stopServer() async {
    _speedTimer?.cancel();
    _sessionPruneTimer?.cancel();
    _networkWatchdog?.cancel();
    _networkWatchdog = null;

    await _httpServer.stop();
    _broadcaster.stop();
    _activeSessions.clear();
    await _serverRepo.markAllOffline();

    await _releaseWakeLock();
    await _releaseBackgroundService();

    notifyListeners();
  }

  List<MediaItem> _getMediaItems() => _mediaRepo.getLocalMediaItems(shareVideos: _shareVideos, shareMusic: _shareMusic, shareImages: _shareImages);

  List<MediaItem> getLocalMediaItems({bool? shareVideos, bool? shareMusic, bool? shareImages}) {
    return _mediaRepo.getLocalMediaItems(shareVideos: shareVideos ?? _shareVideos, shareMusic: shareMusic ?? _shareMusic, shareImages: shareImages ?? _shareImages);
  }

  // ── WakeLock ──────────────────────────────────────────────────────────────

  Future<void> _acquireWakeLock() async {
    if (kIsWeb || _wakeLockHeld) return;
    try {
      await WakelockPlus.enable();
      _wakeLockHeld = true;
      debugPrint('[ServerVM] WakeLock acquired');
    } catch (e) {
      debugPrint('[ServerVM] WakeLock error: $e');
    }
  }

  Future<void> _releaseWakeLock() async {
    if (!_wakeLockHeld) return;
    try {
      await WakelockPlus.disable();
      _wakeLockHeld = false;
      debugPrint('[ServerVM] WakeLock released');
    } catch (e) {
      debugPrint('[ServerVM] WakeLock release error: $e');
    }
  }

  // ── Android Background Service ────────────────────────────────────────────

  Future<void> _acquireBackgroundService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_backgroundActive) return;
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        _backgroundActive = true;
        return;
      }
      const config = FlutterBackgroundAndroidConfig(
        notificationTitle: 'STREAMZ — Server Active',
        notificationText: 'Broadcasting on local network. Tap to open.',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        enableWifiLock: true, // Prevents WiFi from sleeping
      );
      final ok = await FlutterBackground.initialize(androidConfig: config);
      if (ok) {
        await FlutterBackground.enableBackgroundExecution();
        _backgroundActive = true;
        debugPrint('[ServerVM] Background service acquired');
      }
    } catch (e) {
      debugPrint('[ServerVM] Background service error: $e');
    }
  }

  Future<void> _releaseBackgroundService() async {
    if (!_backgroundActive || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
      _backgroundActive = false;
      debugPrint('[ServerVM] Background service released');
    } catch (e) {
      debugPrint('[ServerVM] Background release error: $e');
    }
  }

  // ── Network Watchdog ──────────────────────────────────────────────────────

  void _startNetworkWatchdog() {
    _networkWatchdog?.cancel();
    _networkWatchdog = Timer.periodic(const Duration(seconds: 15), (_) => _checkNetworkAndRestart());
  }

  Future<void> _checkNetworkAndRestart() async {
    if (!isRunning) return;
    try {
      final currentIp = await _detectIp();
      if (currentIp != _serverIp && currentIp != 'No Network' && !currentIp.startsWith('Error')) {
        debugPrint('[ServerVM] IP changed $_serverIp → $currentIp, restarting server');
        _serverIp = currentIp;

        // Hot-restart server on new interface.
        await _httpServer.stop();
        _broadcaster.stop();
        await _httpServer.start(ip: _serverIp, sharedFolders: _sharedFolders, getMediaItems: _getMediaItems);
        await _broadcaster.start(_serverIp);
        notifyListeners();
      }

      // Re-acquire background service if it was dropped (Android only).
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && !FlutterBackground.isBackgroundExecutionEnabled) {
        await _acquireBackgroundService();
      }

      // Re-acquire WakeLock if dropped.
      if (!_wakeLockHeld) await _acquireWakeLock();
    } catch (e) {
      debugPrint('[ServerVM] Network watchdog error: $e');
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

  Future<String> _detectIp() async {
    if (kIsWeb) return '127.0.0.1';
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      String? best;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          // Prefer private LAN addresses.
          if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.') || addr.address.startsWith('172.')) {
            return addr.address;
          }
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
