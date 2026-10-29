// presentation/client/client_viewmodel.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/data/network/media_api_client.dart';
import 'package:streamz/data/network/udp_discovery.dart';
import 'package:streamz/data/repositories/media_repository.dart';
import 'package:streamz/data/repositories/server_repository.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/history_item.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/models/remote_command.dart';
import 'package:streamz/domain/services/device_id_service.dart';
import 'package:streamz/domain/services/download_service.dart';
import 'package:streamz/domain/services/queue_service.dart';
import 'package:streamz/domain/services/remote_command_service.dart';
import 'package:streamz/presentation/player/player_screen.dart';

class ClientViewModel extends ChangeNotifier {
  ClientViewModel() {
    _loadLocalHistory();
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
        if (cmd.action == 'update' && cmd.value is List) {
          sl<QueueService>().updateFromRemote(cmd.value as List);
        }
      }
    });
  }
  final MediaRepository _mediaRepo = sl<MediaRepository>();
  final ServerRepository _serverRepo = sl<ServerRepository>();
  final UdpDiscovery _discovery = sl<UdpDiscovery>();
  final RemoteCommandService remote = sl<RemoteCommandService>();
  final DeviceIdService _deviceId = sl<DeviceIdService>();

  String _targetIp = '';
  // [SECURITY B1] Last pairing token used — reused on reconnects/re-taps of
  // recent nodes so the code doesn't have to be re-entered every time.
  String _lastPairingToken = '';
  bool _isLoading = false;
  bool _isDiscovering = false;
  String? _connectionError;
  List<MediaItem> _remoteMedia = [];
  List<BroadcastStation> _stations = [];
  List<HistoryItem> _localHistory = [];

  final List<String> _ipHistory = [];
  StreamSubscription? _cmdSub;
  Timer? _refreshTimer;

  // Anti-spam timer for remote commands
  DateTime _lastActionTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Getters ───────────────────────────────────────────────────────────────
  String get targetIp => _targetIp;
  bool get isLoading => _isLoading;
  bool get isDiscovering => _isDiscovering;
  String? get connectionError => _connectionError;
  List<MediaItem> get remoteMedia => List.unmodifiable(_remoteMedia);
  List<BroadcastStation> get stations => List.unmodifiable(_stations);
  List<HistoryItem> get localHistory => List.unmodifiable(_localHistory);
  List<String> get ipHistory => List.unmodifiable(_ipHistory);
  bool get isConnected => _targetIp.isNotEmpty;

  /// [SECURITY B1] Non-null when the server rejected the pairing token.
  String? get wsAuthError => remote.authError;

  List<MediaItem> get continueWatching =>
      _mediaRepo.continueWatching(_remoteMedia);

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

  void startDiscovery(void Function(String ip, String? token) onFound) {
    if (_isDiscovering) return;
    _isDiscovering = true;
    notifyListeners();

    _discovery.start((ip, token) {
      _isDiscovering = false;
      notifyListeners();
      onFound(ip, token);
    });
  }

  void stopDiscovery({bool notify = true}) {
    _discovery.stop();
    _isDiscovering = false;
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

    _isLoading = true;
    _connectionError = null;
    notifyListeners();

    try {
      final client = MediaApiClient(ip.trim());
      final ok = await client.ping();
      if (!ok) throw Exception('Server not reachable');

      _targetIp = ip.trim();
      _mediaRepo.client = client;

      _remoteMedia = await _mediaRepo.fetchRemoteMedia();
      _stations = await _mediaRepo.fetchStations();

      // [SECURITY B1] Present the pairing token on the WS upgrade. An empty
      // token still connects the HTTP plane (media) — the WS control plane
      // will fail with 1008 and surface wsAuthError.
      final token = (pairingToken ?? _lastPairingToken).trim();
      _lastPairingToken = token;
      remote.connect(ip.trim(), token: token);
      await _serverRepo.logAccess(ip.trim());

      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => refresh(),
      );

      if (!_ipHistory.contains(ip)) {
        _ipHistory.insert(0, ip);
        if (_ipHistory.length > 5) _ipHistory.removeLast();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _connectionError = e.toString();
      _refreshTimer?.cancel();
      _refreshTimer = null;
      remote.disconnect();
      _mediaRepo.clearClient();
      _targetIp = '';
      _remoteMedia = [];
      _stations = [];
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refresh() async {
    if (_targetIp.isEmpty) return;
    try {
      _remoteMedia = await _mediaRepo.fetchRemoteMedia();
      _stations = await _mediaRepo.fetchStations();
      notifyListeners();
    } catch (_) {}
  }

  // [A3] Sync role elected by the server for the most recent station join.
  // Consumed exactly once by the player screen that opens afterwards.
  String? _pendingSyncRole;

  String? takeStationSyncRole() {
    final role = _pendingSyncRole;
    _pendingSyncRole = null;
    return role;
  }

  Future<StationJoinResponse?> joinStation(String id) async {
    final res = await _mediaRepo.joinStation(id);
    final role = res?.syncRole ?? '';
    _pendingSyncRole = role.isNotEmpty ? role : null;
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
    _refreshTimer?.cancel();
    _refreshTimer = null;
    remote.disconnect();
    _mediaRepo.client = null;
    _targetIp = '';
    _remoteMedia = [];
    notifyListeners();
  }

  /// Preview mode — uses local server as if it were remote
  // ── Remote Browse & Download ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> browseRemote(String path) async {
    if (_targetIp.isEmpty) return [];
    return _mediaRepo.browseRemote(path);
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
    _cmdSub?.cancel();
    _refreshTimer?.cancel();
    stopDiscovery(notify: false);
    super.dispose();
  }
}
