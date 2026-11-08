// presentation/client/client_viewmodel.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/data/network/media_api_client.dart';
import 'package:streamz/data/network/udp_discovery.dart';
import 'package:streamz/data/repositories/media_repository.dart';
import 'package:streamz/data/repositories/server_repository.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/client_connection_phase.dart';
import 'package:streamz/domain/models/history_item.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/models/remote_command.dart';
import 'package:streamz/domain/services/device_id_service.dart';
import 'package:streamz/domain/services/download_service.dart';
import 'package:streamz/domain/services/network_service.dart';
import 'package:streamz/domain/services/queue_service.dart';
import 'package:streamz/domain/services/remote_command_service.dart';
import 'package:streamz/presentation/player/player_screen.dart';

class ClientViewModel extends ChangeNotifier {
  ClientViewModel() {
    _loadLocalHistory();
    remote.onRediscoveryRequested = _recoverConnection;
    remote.addListener(_onRemoteConnectionChanged);
    // Global Navigation Hook: Translates Remote WS Commands into Flutter UI Focus movements
    _cmdSub = remote.commands.listen((cmd) {
      // FIX: Targeted command filtering
      if (cmd.targetId != null && cmd.targetId != _deviceId.id) return;

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
          case 'home':
            if (focus.context != null) {
              Navigator.of(focus.context!).popUntil((route) => route.isFirst);
            }
            break;
          case 'text':
            if (focus.context != null && cmd.value is String) {
              final text = cmd.value as String;
              for (var char in text.runes) {
                final key = String.fromCharCode(char);
                // Simulate a key event for each character using the modern HardwareKeyboard API.
                // Note: targets basic text field entry only — LogicalKeyboardKey is built from the
                // rune, so only printable-ASCII runes map to real keys. Non-ASCII text is not
                // advertised as supported (documented limitation, C12).
                HardwareKeyboard.instance.handleKeyEvent(
                  KeyDownEvent(
                    logicalKey: LogicalKeyboardKey(char),
                    physicalKey: PhysicalKeyboardKey.usbReserved,
                    timeStamp: Duration(
                      milliseconds: DateTime.now().millisecondsSinceEpoch,
                    ),
                    character: key,
                  ),
                );
                HardwareKeyboard.instance.handleKeyEvent(
                  KeyUpEvent(
                    logicalKey: LogicalKeyboardKey(char),
                    physicalKey: PhysicalKeyboardKey.usbReserved,
                    timeStamp: Duration(
                      milliseconds: DateTime.now().millisecondsSinceEpoch,
                    ),
                  ),
                );
              }
            }
            break;
        }
      }

      if (cmd.type == 'media' && cmd.action == 'play') {
        // FIX: ServerViewModel.playOnClient() / NOC "play on client" send the
        // full item payload (Map); the dashboard CLI /play sends a title query
        // (String). Both were previously needed but only the String path worked.
        MediaItem? match;
        if (cmd.value is Map<String, dynamic>) {
          match = MediaItem.fromJson(cmd.value as Map<String, dynamic>);
        } else if (cmd.value is String && _remoteMedia.isNotEmpty) {
          final query = (cmd.value as String).toLowerCase();
          match = _remoteMedia.firstWhere(
            (m) => m.title.toLowerCase().contains(query),
            orElse: () => _remoteMedia.first,
          );
        }
        if (match != null) {
          final item = match; // capture promoted value for the closure below
          final focus = FocusManager.instance.primaryFocus;
          if (focus?.context != null) {
            Navigator.push(
              focus!.context!,
              MaterialPageRoute(
                builder: (_) => PlayerScreen(items: [item], startIndex: 0),
              ),
            );
          }
        }
      }

      if (cmd.type == 'system') {
        switch (cmd.action) {
          case 'ready':
            _isRecovering = false;
            _queuedRecoveryIps.clear();
            _lastQueueRevision = -1;
            _recoveryTimer?.cancel();
            _recoveryTimer = null;
            unawaited(refresh());
            break;
          case 'refresh_data':
            refresh();
            break;
          case 'shutdown':
            if (Platform.isAndroid || Platform.isIOS) {
              SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            } else {
              exit(0);
            }
            break;
        }
      }

      if (cmd.type == 'queue') {
        if (cmd.action == 'update' && (cmd.value is List || cmd.value is Map)) {
          final value = cmd.value;
          final revision = value is Map
              ? (value['revision'] as num?)?.toInt()
              : null;
          if (revision == null || revision > _lastQueueRevision) {
            if (revision != null) _lastQueueRevision = revision;
            sl<QueueService>().updateFromRemote(value);
          }
        }
      }
    });
  }
  final MediaRepository _mediaRepo = sl<MediaRepository>();
  final ServerRepository _serverRepo = sl<ServerRepository>();
  final UdpDiscovery _discovery = sl<UdpDiscovery>();
  final RemoteCommandService remote = sl<RemoteCommandService>();
  final DeviceIdService _deviceId = sl<DeviceIdService>();
  final NetworkService _networkService = sl<NetworkService>();

  String _targetIp = '';
  // [SECURITY B1] Last pairing token used — reused on reconnects/re-taps of
  // recent nodes so the code doesn't have to be re-entered every time.
  String _lastPairingToken = '';
  bool _isLoading = false;
  bool _isDiscovering = false;
  bool _disposed = false;
  bool _isRecovering = false;
  bool _recoveryProbeRunning = false;
  bool _hasRealtimeConnection = false;
  bool _socketWasConnected = false;
  final Set<String> _queuedRecoveryIps = {};
  String _discoveryState = 'idle';
  int _connectionGeneration = 0;
  Future<void>? _refreshInFlight;
  String? _knownServerId;
  String? _connectionError;
  int _lastQueueRevision = -1;
  List<DiscoveredHost> _discoveredHosts = const [];
  List<MediaItem> _remoteMedia = [];
  List<BroadcastStation> _stations = [];
  List<HistoryItem> _localHistory = [];

  final List<String> _ipHistory = [];
  StreamSubscription? _cmdSub;
  StreamSubscription<Object?>? _networkChangeSubscription;
  Timer? _refreshTimer;
  Timer? _recoveryTimer;
  Timer? _networkChangeDebounce;

  // Anti-spam timer for remote commands
  DateTime _lastActionTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Getters ───────────────────────────────────────────────────────────────
  String get targetIp => _targetIp;
  bool get isLoading => _isLoading;
  bool get isDiscovering => _isDiscovering;
  String get discoveryState => _discoveryState;
  List<DiscoveredHost> get discoveredHosts =>
      List.unmodifiable(_discoveredHosts);
  String? get connectionError => _connectionError;
  List<MediaItem> get remoteMedia => List.unmodifiable(_remoteMedia);
  List<BroadcastStation> get stations => List.unmodifiable(_stations);
  List<HistoryItem> get localHistory => List.unmodifiable(_localHistory);
  List<String> get ipHistory => List.unmodifiable(_ipHistory);
  bool get isConnected => remote.isConnected;
  bool get isRealtimeConnected => isConnected;
  ClientConnectionPhase get connectionPhase => resolveClientConnectionPhase(
    isConnected: remote.isConnected,
    isLoading: _isLoading,
    isDiscovering: _isDiscovering,
    hasConnectedBefore: _hasRealtimeConnection,
    socketConnecting: remote.isConnecting,
    socketReconnecting: remote.isReconnecting,
    hasError: _connectionError != null,
    hasAuthenticationError: remote.authError != null,
  );

  void _onRemoteConnectionChanged() {
    if (_disposed) return;
    if (remote.authError != null) {
      _connectionError = remote.authError;
    } else if (remote.isConnected) {
      final recoveredSocket = _hasRealtimeConnection && !_socketWasConnected;
      _socketWasConnected = true;
      _hasRealtimeConnection = true;
      _connectionError = null;
      if (recoveredSocket) {
        unawaited(_refreshAfterReconnect(_connectionGeneration));
      }
    } else if (_hasRealtimeConnection && _targetIp.isNotEmpty) {
      _socketWasConnected = false;
      _connectionError = 'Connection lost. Reconnecting…';
    }
    notifyListeners();
  }

  Future<void> _refreshAfterReconnect(int generation) async {
    try {
      final isHealthy = await _mediaRepo.ping();
      if (_disposed || generation != _connectionGeneration) return;
      if (!isHealthy) {
        _connectionError = 'Server reconnected; waiting for media service…';
        notifyListeners();
        return;
      }
      await refresh();
    } catch (_) {
      if (_disposed || generation != _connectionGeneration) return;
      _connectionError = 'Unable to refresh shared media. Showing saved data.';
      notifyListeners();
    }
  }

  void _startNetworkMonitoring() {
    if (kIsWeb || !Platform.isAndroid || _networkChangeSubscription != null) {
      return;
    }
    _networkChangeSubscription = _networkService.networkChanges.listen((_) {
      if (_disposed || _targetIp.isEmpty || remote.authError != null) return;
      _networkChangeDebounce?.cancel();
      _networkChangeDebounce = Timer(const Duration(milliseconds: 350), () {
        if (_disposed || _targetIp.isEmpty || remote.authError != null) return;
        remote.reconnectAfterNetworkChange();
        _recoverConnection();
      });
    });
  }

  void _stopNetworkMonitoring() {
    _networkChangeDebounce?.cancel();
    _networkChangeDebounce = null;
    unawaited(_networkChangeSubscription?.cancel());
    _networkChangeSubscription = null;
  }

  /// [SECURITY B1] Non-null when the server rejected the pairing token.
  String? get wsAuthError => remote.authError;

  List<MediaItem> get continueWatching =>
      _mediaRepo.continueWatching(_remoteMedia);

  List<MediaItem> get favoriteItems => _mediaRepo.favoriteItems(_remoteMedia);

  bool isFavorite(String id) => _mediaRepo.isFavorite(id);

  Future<void> toggleFavorite(MediaItem item) async {
    await _mediaRepo.toggleFavorite(item);
    if (!_disposed) notifyListeners();
  }

  List<MediaItem> get recentlyPlayed {
    final byId = {for (final item in _remoteMedia) item.id: item};
    final inProgressIds = continueWatching.map((item) => item.id).toSet();
    return _localHistory
        .map((entry) => byId[entry.media.id])
        .whereType<MediaItem>()
        .where((item) => !inProgressIds.contains(item.id))
        .take(20)
        .toList(growable: false);
  }

  List<MediaItem> get videos => _remoteMedia.where((m) => m.isVideo).toList();
  List<MediaItem> get audio => _remoteMedia.where((m) => m.isAudio).toList();
  List<MediaItem> get images => _remoteMedia.where((m) => m.isImage).toList();

  // ── Discovery ─────────────────────────────────────────────────────────────

  Future<void> startDiscovery(
    void Function(String ip, String? token) onFound,
  ) async {
    if (_isDiscovering || _disposed) return;
    if (!await _networkService.ensureLocalNetworkAccess()) {
      _connectionError =
          'Allow local network access to find and connect to servers.';
      _discoveryState = 'failed';
      notifyListeners();
      return;
    }
    _isDiscovering = true;
    _discoveryState = 'scanning';
    _discoveredHosts = const [];
    _connectionError = null;
    notifyListeners();

    await _discovery.start(
      (ip, token) {
        _discoveryState = 'found';
        notifyListeners();
        onFound(ip, token);
      },
      onHostsChanged: (hosts) {
        if (_disposed) return;
        _discoveredHosts = hosts;
        if (hosts.isNotEmpty) _discoveryState = 'found';
        notifyListeners();
        if (_isRecovering) _recoverFromMdns(hosts);
      },
      onFinished: () {
        if (_disposed) return;
        _isDiscovering = false;
        if (_discoveredHosts.isNotEmpty) {
          _discoveryState = 'found';
        } else if (_discovery.failure != null) {
          _discoveryState = 'failed';
          _connectionError =
              'Could not search this network. Check Wi-Fi and try again.';
        } else {
          _discoveryState = 'timedOut';
        }
        notifyListeners();
        if (_isRecovering) {
          _recoveryTimer?.cancel();
          _recoveryTimer = Timer(const Duration(seconds: 8), () {
            _isRecovering = false;
            _queuedRecoveryIps.clear();
            _recoverConnection();
          });
        }
      },
    );
  }

  void stopDiscovery({bool notify = true}) {
    _discovery.stop();
    _isDiscovering = false;
    if (_discoveryState == 'scanning') _discoveryState = 'cancelled';
    if (notify) notifyListeners();
  }

  // ── Connection ────────────────────────────────────────────────────────────

  Future<bool> connect(String ip, {String? pairingToken}) async {
    if (_isLoading) {
      return false; // [FIX]: Prevent parallel connections on rapid taps
    }

    if (ip.trim().isEmpty) {
      _connectionError = 'Enter an IP address';
      notifyListeners();
      return false;
    }

    final generation = ++_connectionGeneration;
    _stopNetworkMonitoring();
    _isRecovering = false;
    _queuedRecoveryIps.clear();
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _refreshInFlight = null;
    _isLoading = true;
    _hasRealtimeConnection = false;
    _socketWasConnected = false;
    _connectionError = null;
    notifyListeners();

    MediaApiClient? candidateClient;
    try {
      if (!await _networkService.ensureLocalNetworkAccess()) {
        throw Exception('Allow local network access to connect to a server.');
      }
      if (_disposed || generation != _connectionGeneration) return false;
      candidateClient = MediaApiClient(ip.trim());
      final ok = await candidateClient.ping();
      if (!ok) throw Exception('Server not reachable');
      if (_disposed || generation != _connectionGeneration) {
        candidateClient.close();
        candidateClient = null;
        return false;
      }

      _targetIp = ip.trim();
      _knownServerId = _discovery.hosts
          .where((host) => host.ip == _targetIp && host.viaMdns)
          .map((host) => host.hostId)
          .firstOrNull;
      _mediaRepo.client = candidateClient;
      candidateClient = null;

      await _loadRemoteState(generation: generation);
      if (_disposed || generation != _connectionGeneration) return false;

      // [SECURITY B1] Present the pairing token on the WS upgrade. An empty
      // token still connects the HTTP plane (media) — the WS control plane
      // will fail with 1008 and surface wsAuthError.
      final token = (pairingToken ?? _lastPairingToken).trim();
      _lastPairingToken = token;
      remote.connect(ip.trim(), token: token);
      await _serverRepo.logAccess(ip.trim());
      if (_disposed || generation != _connectionGeneration) return false;
      _startNetworkMonitoring();

      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(refresh()),
      );

      if (!_ipHistory.contains(ip)) {
        _ipHistory.insert(0, ip);
        if (_ipHistory.length > 5) _ipHistory.removeLast();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      candidateClient?.close();
      if (_disposed || generation != _connectionGeneration) return false;
      _stopNetworkMonitoring();
      _connectionError = e.toString();
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _targetIp = '';
      _hasRealtimeConnection = false;
      remote.disconnect();
      _mediaRepo.clearClient();
      _remoteMedia = [];
      _stations = [];
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refresh() {
    if (_disposed || _targetIp.isEmpty) return Future<void>.value();
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final generation = _connectionGeneration;
    late final Future<void> refreshFuture;
    refreshFuture = _refreshRemoteState(generation).whenComplete(() {
      if (identical(_refreshInFlight, refreshFuture)) _refreshInFlight = null;
    });
    _refreshInFlight = refreshFuture;
    return refreshFuture;
  }

  Future<void> _refreshRemoteState(int generation) async {
    try {
      final stationsLoaded = await _loadRemoteState(generation: generation);
      if (_disposed || generation != _connectionGeneration) return;
      if (stationsLoaded && remote.isConnected) {
        _connectionError = null;
      } else if (!stationsLoaded) {
        _connectionError =
            'Unable to refresh stations. Showing the last available data.';
      }
      notifyListeners();
    } catch (_) {
      if (!_disposed && generation == _connectionGeneration) {
        _connectionError =
            'Unable to refresh shared media. Showing saved data.';
        notifyListeners();
      }
    }
  }

  Future<bool> _loadRemoteState({required int generation}) async {
    var stationsLoaded = true;
    final state = await Future.wait<Object>([
      _mediaRepo.fetchRemoteMedia(),
      _mediaRepo.fetchStations().catchError((Object error) {
        stationsLoaded = false;
        return _stations;
      }),
    ]);
    if (_disposed || generation != _connectionGeneration) return false;
    _remoteMedia = state[0] as List<MediaItem>;
    _stations = state[1] as List<BroadcastStation>;
    return stationsLoaded;
  }

  void _recoverConnection() {
    if (_disposed || _targetIp.isEmpty || _isRecovering) return;
    _isRecovering = true;
    unawaited(
      startDiscovery((ip, token) {
        if (token == _lastPairingToken) {
          unawaited(_recoverToHost(ip));
        } else {
          _discovery.stop();
          _isDiscovering = false;
          _isRecovering = false;
          _queuedRecoveryIps.clear();
          _recoveryTimer?.cancel();
          _recoveryTimer = Timer(
            const Duration(seconds: 1),
            _recoverConnection,
          );
        }
      }),
    );
  }

  void _recoverFromMdns(List<DiscoveredHost> hosts) {
    final knownServerId = _knownServerId;
    if (!_isRecovering || knownServerId == null) return;
    _queuedRecoveryIps.addAll(
      UdpDiscovery.mdnsAddressesForHost(hosts, knownServerId),
    );
    unawaited(_recoverQueuedHosts());
  }

  Future<void> _recoverToHost(String ip) async {
    if (ip.isEmpty || !_isRecovering || _disposed) return;
    _queuedRecoveryIps.add(ip);
    final knownServerId = _knownServerId;
    if (knownServerId != null) {
      _queuedRecoveryIps.addAll(
        UdpDiscovery.mdnsAddressesForHost(_discovery.hosts, knownServerId),
      );
    }
    await _recoverQueuedHosts();
  }

  Future<void> _recoverQueuedHosts() async {
    if (_disposed || !_isRecovering || _recoveryProbeRunning) return;
    _recoveryProbeRunning = true;
    try {
      while (_queuedRecoveryIps.isNotEmpty && !_disposed && _isRecovering) {
        final ip = _queuedRecoveryIps.first;
        _queuedRecoveryIps.remove(ip);
        final client = MediaApiClient(ip);
        if (!await client.ping()) {
          client.close();
          continue;
        }
        if (_disposed || !_isRecovering) {
          client.close();
          return;
        }
        _targetIp = ip;
        _mediaRepo.client = client;
        stopDiscovery(notify: false);
        remote.connect(ip, token: _lastPairingToken);
        _isRecovering = false;
        _queuedRecoveryIps.clear();
        _recoveryTimer?.cancel();
        _recoveryTimer = null;
        _discoveryState = 'found';
        notifyListeners();
        return;
      }
    } finally {
      _recoveryProbeRunning = false;
    }
  }

  // [A3] Sync role elected by the server for the most recent station join.
  // Consumed exactly once by the player screen that opens afterwards.
  String? _pendingSyncRole;
  String? _pendingStationId;
  int? _pendingStationRevision;

  String? takeStationId() {
    final stationId = _pendingStationId;
    _pendingStationId = null;
    return stationId;
  }

  int? takeStationRevision() {
    final revision = _pendingStationRevision;
    _pendingStationRevision = null;
    return revision;
  }

  String? takeStationSyncRole() {
    final role = _pendingSyncRole;
    _pendingSyncRole = null;
    return role;
  }

  Future<StationJoinResponse?> joinStation(String id) async {
    final res = await _mediaRepo.joinStation(id);
    final role = res?.syncRole ?? '';
    _pendingSyncRole = role.isNotEmpty ? role : null;
    _pendingStationId = res == null ? null : id;
    _pendingStationRevision = res?.stationRevision;
    return res;
  }

  // ── History ──────────────────────────────────────────────────────────────

  void _loadLocalHistory() {
    try {
      _localHistory = _mediaRepo.getLocalHistory();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addToHistory(MediaItem item) async {
    await _mediaRepo.addToHistory(item);
    _loadLocalHistory();
  }

  Future<void> refreshPlaybackProgress() async {
    // Let player-route disposal finish before notifying widgets underneath it.
    await Future<void>.delayed(Duration.zero);
    _remoteMedia = _mediaRepo.withLocalProgress(_remoteMedia);
    notifyListeners();
  }

  void disconnect() {
    _connectionGeneration++;
    _stopNetworkMonitoring();
    _refreshInFlight = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _isRecovering = false;
    _queuedRecoveryIps.clear();
    _isLoading = false;
    _targetIp = '';
    _hasRealtimeConnection = false;
    _socketWasConnected = false;
    _connectionError = null;
    remote.disconnect();
    _mediaRepo.client = null;
    _remoteMedia = [];
    _stations = [];
    notifyListeners();
  }

  /// Preview mode — uses local server as if it were remote
  // ── Remote Browse & Download ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> browseRemote(String path) async {
    if (_targetIp.isEmpty) return [];
    return _mediaRepo.browseRemote(path);
  }

  Future<BrowsePage> browseRemotePage(
    String path, {
    required int offset,
    int limit = 200,
    String query = '',
    String sortBy = 'name',
    bool ascending = true,
  }) async {
    if (_targetIp.isEmpty) {
      return const BrowsePage(items: [], total: 0, hasMore: false);
    }
    return _mediaRepo.browseRemotePage(
      path,
      offset: offset,
      limit: limit,
      query: query,
      sortBy: sortBy,
      ascending: ascending,
    );
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

  void sendNav(String action, [dynamic value]) {
    remote.send(RemoteCommand('nav', action, value, null, _deviceId.id));
  }

  void sendText(String text) {
    remote.send(RemoteCommand('nav', 'text', text, null, _deviceId.id));
  }

  void sendQueueCommand(String action, dynamic value) {
    remote.send(RemoteCommand('queue', action, value, null, _deviceId.id));
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionGeneration++;
    _stopNetworkMonitoring();
    _refreshInFlight = null;
    remote.onRediscoveryRequested = null;
    remote.removeListener(_onRemoteConnectionChanged);
    _cmdSub?.cancel();
    _refreshTimer?.cancel();
    _recoveryTimer?.cancel();
    stopDiscovery(notify: false);
    _mediaRepo.clearClient();
    super.dispose();
  }
}
