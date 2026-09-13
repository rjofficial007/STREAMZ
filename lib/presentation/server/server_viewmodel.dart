// presentation/server/server_viewmodel.dart
// ============================================================================
// STREAMZ — Server ViewModel (Production-Fixed)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/core/util/lifecycle_broadcaster.dart';
import 'package:streamz/core/utils/logger.dart';
import 'package:streamz/data/local/media_scanner.dart';
import 'package:streamz/data/network/http_server.dart';
import 'package:streamz/data/network/udp_discovery.dart';
import 'package:streamz/data/repositories/media_repository.dart';
import 'package:streamz/data/repositories/server_repository.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/connection_record.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/models/stream_session.dart';
import 'package:streamz/domain/services/network_service.dart';
import 'package:streamz/domain/services/platform_service.dart';
import 'package:streamz/domain/services/server_lifecycle_service.dart';
import 'package:streamz/domain/services/video_thumbnail_service.dart';

class ServerViewModel extends ChangeNotifier {

  // ── Constructor ───────────────────────────────────────────────────────────

  ServerViewModel() {
    // Load default folders based on platform logic in PlatformService.
    _sharedFolders = sl<PlatformService>().getDefaultSharedFolders();
    // [E1] Restore persisted settings (overrides defaults if present).
    _loadSettings();
    _loadStations();
    _wireCallbacks();
    _ensurePairingToken();
    _httpServer.useModernWebUI = _useModernWebUI;

    // Subscribe to app lifecycle events from the root observer.
    _lifecycleBus.addManualListener(_onLifecycleChange);

    // Wire up ServerLifecycleService callbacks
    _lifecycleService.onNetworkChange = (newIp) async {
      if (!isRunning) return;
      // [FIX C9] Generation token: if a newer change (or stopServer)
      // supersedes this restart mid-flight, abandon it instead of
      // interleaving.
      final gen = ++_restartGeneration;
      logger.i('[ServerVM] IP changed to $newIp, restarting server');
      _serverIp = newIp;
      await _httpServer.stop();
      _broadcaster.stop();
      if (gen != _restartGeneration) return; // superseded
      _httpServer.pairingToken = _pairingToken;
      await _httpServer.start(ip: _serverIp, sharedFolders: _sharedFolders, getMediaItems: _getMediaItems);
      if (gen != _restartGeneration) return; // superseded
      await _broadcaster.start(_serverIp, _pairingToken);
      notifyListeners();
    };
  }
  final HttpServerService _httpServer = sl<HttpServerService>();
  final UdpBroadcaster _broadcaster = sl<UdpBroadcaster>();
  final MediaScanner _scanner = sl<MediaScanner>();
  final MediaRepository _mediaRepo = sl<MediaRepository>();
  final ServerRepository _serverRepo = sl<ServerRepository>();
  final AppLifecycleBroadcaster _lifecycleBus = sl<AppLifecycleBroadcaster>();
  final NetworkService _networkService = sl<NetworkService>();
  final ServerLifecycleService _lifecycleService = sl<ServerLifecycleService>();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isInitializing = false;
  // [FIX C2] One-shot retry flag for port-in-use recovery.
  bool _startRetried = false;
  // [FIX C9] Restart generation token — rapid successive network changes
  // must not interleave stop/start pairs (a stale restart could resurrect a
  // server a newer change or a manual stop already tore down).
  int _restartGeneration = 0;
  String _serverIp = 'Initializing...';

  bool _useModernWebUI = true;
  bool _shareVideos = true;
  bool _shareImages = true;
  bool _shareMusic = true;
  bool _zeroTrace = false;
  List<String> _sharedFolders = [];
  List<BroadcastStation> _stations = [];

  final Map<String, StreamSession> _activeSessions = {};

  // UI-facing timers — cancelled on widget dispose, NOT on server stop.
  Timer? _sessionPruneTimer;
  Timer? _speedTimer;

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
  bool get zeroTrace => _zeroTrace;
  List<String> get sharedFolders => List.unmodifiable(_sharedFolders);
  List<BroadcastStation> get stations => List.unmodifiable(_stations);
  List<StreamSession> get activeSessions => _activeSessions.values.toList();
  List<ConnectionRecord> get connectionHistory => _serverRepo.connectionHistory;
  int get connectedClients => _httpServer.socketCount;
  double get currentSpeedMb => _currentSpeedMb;
  List<String> get serverLogs => _httpServer.logs;

  void _loadStations() {
    final list = _serverRepo.loadStations();
    _stations = list.map(BroadcastStation.fromJson).toList();
    _httpServer.stations = _stations;
  }

  Future<void> _saveStations() async {
    await _serverRepo.saveStations(_stations.map((e) => e.toJson()).toList());
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
      if (_zeroTrace) return;
      final changed = await _serverRepo.logAccess(ip);
      if (changed) notifyListeners();
    };

    _httpServer.onSocketsChanged = notifyListeners;
  }

  // ── App Lifecycle ─────────────────────────────────────────────────────────

  void _onLifecycleChange(AppLifecycleState state) {
    if (!isRunning) return;
    _lifecycleService.onAppLifecycleChanged(state);
  }

  // ── Server Lifecycle ──────────────────────────────────────────────────────

  Future<void> startServer() async {
    if (isRunning || _isInitializing) return;
    _isInitializing = true;
    notifyListeners();

    try {
      _serverIp = await _networkService.detectIp();

      // Acquire keep-alive mechanisms BEFORE the server starts.
      await _lifecycleService.acquire(serverIp: _serverIp);

      // Scan media...
      await _scanner.scanPhotoManager(includeVideos: _shareVideos, includeImages: _shareImages);
      await _scanner.scanAudio();

      // Scan manually shared directories.
      _scanner.clearScannedFiles();
      for (final folder in _sharedFolders) {
        await _scanner.scanDirectory(
          folder, 
          includeVideos: _shareVideos, 
          includeAudio: _shareMusic, 
          includeImages: _shareImages, 
          onBatch: (_) => notifyListeners()
        );
      }

      _httpServer.pairingToken = _pairingToken;
      await _httpServer.start(ip: _serverIp, sharedFolders: _sharedFolders, getMediaItems: _getMediaItems);

      await _broadcaster.start(_serverIp, _pairingToken);
      _startUITimers();
      _startRetried = false; // success — re-arm the one-shot retry
    } catch (e) {
      logger.e('[ServerVM] Start error', error: e);
      await _lifecycleService.release();
      // [FIX C2] A lingering socket from a previous run can briefly hold
      // port 8080. Retry once after a pause; if that also fails, surface a
      // readable first line instead of the raw multi-line exception.
      if (!_startRetried) {
        _startRetried = true;
        _serverIp = 'Retrying...';
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
        unawaited(startServer());
        return;
      }
      _serverIp = 'Error: ${e.toString().split('\n').first}';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    logger.i('[ServerVM] Stopping server...');
    _restartGeneration++; // [FIX C9] invalidate any in-flight restart
    _speedTimer?.cancel();
    _sessionPruneTimer?.cancel();

    try {
      await Future.any([
        Future.wait([
          _httpServer.stop(),
          Future.microtask(_broadcaster.stop),
        ]),
        Future.delayed(const Duration(seconds: 3), () => logger.w('[ServerVM] Stop timeout')),
      ]);
    } catch (e) {
      logger.e('[ServerVM] Error during stop', error: e);
    }

    _activeSessions.clear();
    await _serverRepo.markAllOffline();
    await _lifecycleService.release();

    logger.i('[ServerVM] Server stopped');
    notifyListeners();
  }

  List<MediaItem> _getMediaItems() => _mediaRepo.getLocalMediaItems(shareVideos: _shareVideos, shareMusic: _shareMusic, shareImages: _shareImages);

  List<MediaItem> getLocalMediaItems({bool? shareVideos, bool? shareMusic, bool? shareImages}) => _mediaRepo.getLocalMediaItems(shareVideos: shareVideos ?? _shareVideos, shareMusic: shareMusic ?? _shareMusic, shareImages: shareImages ?? _shareImages);

  // ── Communication ────────────────────────────────────────────────────────

  void broadcastCommand(String type, String action, {dynamic value, String? targetId}) {
    final payload = {
      'type': type,
      'action': action,
      'senderId': 'SERVER',
      'value': value,
      'targetId': targetId,
    };
    _httpServer.broadcast(jsonEncode(payload));
  }

  void sendIntercom(String text) {
    if (text.isEmpty) return;
    _httpServer.broadcast(jsonEncode({
      'type': 'intercom',
      'action': 'alert',
      'value': text,
    }));
  }

  void playOnClient(MediaItem item, {String? targetId}) {
    broadcastCommand('media', 'play', value: item.toJson(), targetId: targetId);
  }

  void stopClient(String clientId) {
    broadcastCommand('media', 'stop', targetId: clientId);
  }

  void teleport(String fromId, String toId) {
    // Session retrieval by clientId. We assume the session is active if the node is connected.
    final session = _activeSessions.values.firstWhere((s) => s.clientId == fromId, orElse: () => throw Exception('Session not found'));
    
    // Teleportation logic:
    // 1. Tell the source node to stop.
    // 2. Tell the target node to start playing the SAME media at the SAME position.
    stopClient(fromId);
    broadcastCommand(
      'media', 
      'teleport', 
      value: {
        'mediaId': session.mediaId,
        'position': session.position,
        'mediaType': session.mediaType,
      }, 
      targetId: toId
    );
  }

  // ── Pairing (WS control-plane auth) ───────────────────────────────────────

  /// [SECURITY B1] Pairing token for the WS control plane. Stable per device
  /// (persisted) — it's the LAN access code. Shown on the QR sheet and
  /// encoded in the QR / UDP announcements.
  String _pairingToken = '';
  String get pairingToken => _pairingToken;

  /// QR payload: a web client opened at this URL carries the token in its
  /// location and presents it on the WS upgrade.
  String get pairingUrl => 'http://$_serverIp:8080/?token=$_pairingToken';

  void _ensurePairingToken() {
    final prefs = sl<SharedPreferences>();
    final existing = prefs.getString('pairing_token');
    if (existing != null && existing.isNotEmpty) {
      _pairingToken = existing;
      return;
    }
    // Unambiguous alphabet (no 0/O/1/I/L); 8 chars ≈ 2^40 — plenty for a
    // LAN pairing code, short enough to type by hand.
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    _pairingToken = List.generate(8, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
    prefs.setString('pairing_token', _pairingToken);
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  /// [E1] Restore server settings so a restart doesn't wipe mounted
  /// folders, filters, the web-UI toggle, or no-trace mode.
  void _loadSettings() {
    final s = _serverRepo.loadSettings();
    final folders = s['sharedFolders'];
    if (folders is List) {
      _sharedFolders = folders.whereType<String>().toList();
    }
    _useModernWebUI = s['useModernWebUI'] as bool? ?? _useModernWebUI;
    _shareVideos = s['shareVideos'] as bool? ?? _shareVideos;
    _shareImages = s['shareImages'] as bool? ?? _shareImages;
    _shareMusic = s['shareMusic'] as bool? ?? _shareMusic;
    _zeroTrace = s['zeroTrace'] as bool? ?? _zeroTrace;
  }

  void _saveSettings() {
    unawaited(_serverRepo.saveSettings({
      'sharedFolders': _sharedFolders,
      'useModernWebUI': _useModernWebUI,
      'shareVideos': _shareVideos,
      'shareImages': _shareImages,
      'shareMusic': _shareMusic,
      'zeroTrace': _zeroTrace,
    }));
  }

  void setUseModernWebUI(bool v) {
    _useModernWebUI = v;
    _httpServer.useModernWebUI = v;
    _saveSettings();
    notifyListeners();
  }

  void setShareVideos(bool v) {
    _shareVideos = v;
    _saveSettings();
    notifyListeners();
  }

  void setShareImages(bool v) {
    _shareImages = v;
    _saveSettings();
    notifyListeners();
  }

  void setShareMusic(bool v) {
    _shareMusic = v;
    _saveSettings();
    notifyListeners();
  }

  void setZeroTrace(bool v) {
    _zeroTrace = v;
    _saveSettings();
    notifyListeners();
  }

  void addSharedFolder(String path) {
    if (!_sharedFolders.contains(path)) {
      _sharedFolders.add(path);
      _saveSettings();
      notifyListeners();
    }
  }

  void removeSharedFolder(String path) {
    _sharedFolders.remove(path);
    _saveSettings();
    notifyListeners();
  }

  void forgetConnection(ConnectionRecord record) {
    _serverRepo.forgetConnection(record.ip);
    notifyListeners();
  }

  // ── Station Management ──────────────────────────────────────────────────

  /// [FIX A3]: resolves real durations for directory-scanned items
  /// (duration == 0) so the station clock computes correct offsets.
  /// Without this, any station containing scanned media has a zero (or
  /// wrong) totalDuration and /api/stations/join returns 404 or drifts.
  Future<void> createStation(String name, List<MediaItem> items) async {
    if (items.isEmpty) return;
    // ponytail: probes are serialized through the single headless MPV player
    // (~150-300 ms per item) — fine for an explicit user action.
    // Upgrade path: parallel native probing / persist probed durations to prefs.
    final resolved = <MediaItem>[];
    for (final it in items) {
      if (it.duration == 0 && !it.isImage) {
        final d = await _probeDuration(it);
        resolved.add(d > 0 ? it.copyWith(duration: d) : it);
      } else {
        resolved.add(it);
      }
    }
    final station = BroadcastStation(
      id: 'STN_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      playlist: resolved,
      startTime: DateTime.now(),
      isActive: true,
      isPaused: false,
    );
    _stations.add(station);
    _httpServer.stations = _stations;
    await _saveStations();
    broadcastCommand('system', 'refresh_data');
    notifyListeners();
  }

  Future<void> toggleStationPlayback(String stationId) async {
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
    await _saveStations();
    broadcastCommand('system', 'refresh_data');
    notifyListeners();
  }

  Future<void> toggleStationActive(String stationId) async {
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

    // Re-run sync-master election on next join.
    _httpServer.clearStationMaster(stationId);
    _httpServer.stations = _stations;
    await _saveStations();
    broadcastCommand('system', 'refresh_data');
    notifyListeners();
  }

  Future<void> removeStation(String id) async {
    _stations.removeWhere((s) => s.id == id);
    _httpServer.clearStationMaster(id);
    _httpServer.stations = _stations;
    await _saveStations();
    broadcastCommand('system', 'refresh_data');
    notifyListeners();
  }

  Future<void> curateStation(String vibe) async {
    final all = _mediaRepo.getLocalMediaItems(shareVideos: true, shareMusic: true, shareImages: false);
    var filtered = <MediaItem>[];
    if (vibe == 'video') {
      filtered = all.where((m) => m.isVideo).toList();
    } else if (vibe == 'audio') {
      filtered = all.where((m) => m.isAudio).toList();
    } else {
      filtered = all;
    }
    if (filtered.isEmpty) return;
    filtered.shuffle();
    await createStation('AUTO_${vibe.toUpperCase()}', filtered.take(15).toList());
  }

  Future<int> _probeDuration(MediaItem item) async {
    if (kIsWeb) return 0;
    final file = _scanner.fileById(item.id);
    if (file != null && file.existsSync()) {
      return sl<VideoThumbnailService>().probeDuration(file.path);
    }
    // Path-based items (id IS the file path).
    final raw = File(item.id);
    if (raw.existsSync()) return sl<VideoThumbnailService>().probeDuration(item.id);
    return 0;
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

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // CRITICAL: Do NOT call stopServer() here.
    // The HTTP server must outlive the ServerDashboard widget.
    _speedTimer?.cancel();
    _sessionPruneTimer?.cancel();
    _lifecycleBus.removeManualListener(_onLifecycleChange);
    super.dispose();
  }
}
