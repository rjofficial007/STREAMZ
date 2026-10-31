// data/network/http_server.dart
// ============================================================================
// STREAMZ — Local HTTP Server (Production-Fixed)
//
// BUGS FIXED:
//   1. Path traversal check stripped '..' with string replace but did NOT
//      handle URL-encoded variants (%2e%2e, %2F etc.) or OS-level symlinks.
//      Fixed: decode the path before normalisation, then use
//      path.canonicalize() so symlinks are resolved before comparison.
//   2. _sockets was typed List (dynamic) — unsafe. Now List<WebSocketSink>
//      (via the web_socket_channel WebSocket abstraction).
//   3. No timeout on /api/browse directory listing — a stalled filesystem
//      call could hang the HTTP handler indefinitely. Added 10 s timeout.
//   4. Serving files with Range header did not validate that `end >= start`
//      or that the range was within the file, which could cause a 206 with
//      negative Content-Length. Added clamp guards.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:streamz/core/utils/file_type_utils.dart';
import 'package:streamz/core/utils/logger.dart';
import 'package:streamz/data/local/media_scanner.dart';
import 'package:streamz/data/local/thumbnail_cache.dart';
import 'package:streamz/data/network/async_request_semaphore.dart';
import 'package:streamz/data/network/web_interface_html.dart';
import 'package:streamz/data/repositories/server_repository.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/history_item.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/models/stream_session.dart';
import 'package:streamz/domain/services/queue_service.dart';
import 'package:streamz/domain/services/station_service.dart';
import 'package:streamz/domain/services/video_thumbnail_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef SessionUpdateCallback =
    void Function(String sessionId, StreamSession? session);
typedef ConnectionLogCallback = void Function(String ip);

class _BrowseDirectoryCache {
  _BrowseDirectoryCache(this.createdAt, this.entries);

  final DateTime createdAt;
  final List<Map<String, dynamic>> entries;
  bool sizesLoaded = false;
}

class _BrowseCapacityException implements Exception {}

class HttpServerService {
  HttpServerService({
    required MediaScanner scanner,
    required ThumbnailCache thumbCache,
    required VideoThumbnailService thumbGenerator,
    required StationService stationService,
    required QueueService queueService,
    required ServerRepository serverRepository,
  }) : _scanner = scanner,
       _thumbCache = thumbCache,
       _thumbGenerator = thumbGenerator,
       _stationService = stationService,
       _queueService = queueService,
       _serverRepository = serverRepository;
  final MediaScanner _scanner;
  final ThumbnailCache _thumbCache;
  final VideoThumbnailService _thumbGenerator;
  final StationService _stationService;
  final QueueService _queueService;
  final ServerRepository _serverRepository;

  HttpServer? _server;

  List<BroadcastStation> _stations = [];
  int _stationRevision = 0;

  set stations(List<BroadcastStation> value) {
    _stations = value;
    _stationRevision++;
  }

  List<BroadcastStation> get stations => _stations;

  // [A3] station id -> elected sync-master client id (first Flutter joiner
  // since the station was (re)activated). Web joiners don't participate.
  final Map<String, String> _stationMasters = {};
  final Map<String, Set<String>> _clientStations = {};
  final Map<String, Set<String>> _stationClients = {};
  final Map<String, _BrowseDirectoryCache> _browseDirectoryCache = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _browseLoads = {};
  final Map<String, Future<shelf.Response>> _thumbnailLoads = {};
  int _browseCacheGeneration = 0;

  // [SECURITY B1] Pairing token for the WS control plane. Set by the
  // ServerViewModel before start(). The HTTP media plane stays open —
  // sharing is the point of the app; only control requires the token.
  String pairingToken = '';

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // FIX: Typed list instead of List<dynamic>.
  final List<WebSocketChannel> _sockets = [];
  final Map<String, WebSocketChannel> _clientSockets = {};
  final Map<String, DateTime> _clientLastHeartbeat = {};
  final List<String> _logs = [];
  int _totalBytesSent = 0;
  int _catalogBytesSent = 0;
  int _activeStreams = 0;
  int _syncSequence = 0;
  static const int _maxWebSocketClients = 32;
  static const int _maxConcurrentStreams = 8;
  static const Duration _clientHeartbeatTimeout = Duration(seconds: 45);
  static const Duration _heartbeatSweepInterval = Duration(seconds: 5);
  // ponytail: cache at most 12 paths, up to 10k entries per path; larger
  // folders re-enumerate per page. Upgrade to cursor-backed enumeration if
  // measurements show this ceiling is common.
  static const int _maxCachedBrowseEntries = 10000;
  static const int _maxCachedBrowseDirectories = 12;
  static const Map<String, String> _browserFontAssets = {
    'Manrope-Variable.ttf': 'assets/fonts/manrope/Manrope-Variable.ttf',
    'Inter-Variable.ttf': 'assets/fonts/inter/Inter-Variable.ttf',
    'Roboto-Variable.ttf': 'assets/fonts/roboto/Roboto-Variable.ttf',
    'Lora-Variable.ttf': 'assets/fonts/lora/Lora-Variable.ttf',
  };
  final AsyncRequestSemaphore _browseRequestLimiter = AsyncRequestSemaphore(
    maxConcurrent: 4,
    maxQueued: 64,
  );
  List<MediaItem> _catalogItems = const [];
  Map<String, MediaItem> _mediaById = const {};
  String? _cachedCatalogRevision;
  String? _cachedCatalogBody;
  String _catalogEpoch = '';
  Future<String>? _catalogBuild;
  List<Map<String, dynamic>>? _cachedQueueSnapshot;
  int? _cachedQueueRevision;
  List<MediaItem> Function()? _getMediaItems;
  String Function()? _getMediaRevision;
  Timer? _logNotifyTimer;
  Timer? _heartbeatWatchdog;
  List<String>? _lastVibeColors;

  SessionUpdateCallback? onSessionUpdate;
  ConnectionLogCallback? onConnection;
  void Function()? onSocketsChanged;

  bool get isRunning => _server != null;
  int get socketCount => _sockets.length;
  int get bytesSent => _totalBytesSent;
  int get catalogBytesSent => _catalogBytesSent;
  int get activeStreams => _activeStreams;
  List<String> get logs => List.unmodifiable(_logs);

  @visibleForTesting
  static bool hasHeartbeatExpired(DateTime lastHeartbeat, DateTime now) =>
      now.difference(lastHeartbeat) > _clientHeartbeatTimeout;

  void _addLog(String message) {
    logger.i('[HttpServer] $message');
    final timestamp = DateTime.now()
        .toString()
        .split(' ')
        .last
        .split('.')
        .first;
    _logs.add('[$timestamp] $message');
    if (_logs.length > 100) _logs.removeAt(0);
    _logNotifyTimer ??= Timer(const Duration(milliseconds: 200), () {
      _logNotifyTimer = null;
      onSocketsChanged?.call();
    });
  }

  // ── Security ───────────────────────────────────────────────────────────────

  /// Returns true only if [rawPath] resolves to a location inside one of
  /// [sharedFolders] after URL-decoding and OS-level canonicalisation.
  @visibleForTesting
  static Future<bool> isPathAllowed(
    String rawPath,
    List<String> sharedFolders,
  ) async {
    if (rawPath.isEmpty) return false;
    try {
      final decoded = Uri.decodeComponent(rawPath);
      final absolutePath = p.absolute(decoded);
      final canonical = p.canonicalize(absolutePath);
      final resolvedPath = await _resolveThroughExistingAncestors(canonical);

      for (final folder in sharedFolders) {
        final canonicalFolder = p.canonicalize(p.absolute(folder));
        final resolvedFolder = await _resolveThroughExistingAncestors(
          canonicalFolder,
        );
        if (resolvedPath == resolvedFolder ||
            p.isWithin(resolvedFolder, resolvedPath)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      logger.e('Path allowed check error: $rawPath', error: e);
      return false;
    }
  }

  /// Resolves symlinks in the existing portion of a path while preserving
  /// missing trailing segments so callers can still return their usual 404.
  static Future<String> _resolveThroughExistingAncestors(String path) async {
    var existing = path;
    final suffix = <String>[];
    while (true) {
      final type = await FileSystemEntity.type(existing, followLinks: false);
      if (type != FileSystemEntityType.notFound) {
        final resolved = switch (type) {
          FileSystemEntityType.directory => await Directory(
            existing,
          ).resolveSymbolicLinks(),
          FileSystemEntityType.link => await Link(
            existing,
          ).resolveSymbolicLinks(),
          _ => await File(existing).resolveSymbolicLinks(),
        };
        return p.canonicalize(p.joinAll([resolved, ...suffix.reversed]));
      }

      final parent = p.dirname(existing);
      if (parent == existing) return path;
      suffix.add(p.basename(existing));
      existing = parent;
    }
  }

  // ── Server Lifecycle ───────────────────────────────────────────────────────

  Future<void> start({
    required String ip,
    required List<String> sharedFolders,
    required List<MediaItem> Function() getMediaItems,
    required String Function() getMediaRevision,
  }) async {
    if (_server != null) await stop();
    _getMediaItems = getMediaItems;
    _getMediaRevision = getMediaRevision;
    _catalogEpoch = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    _cachedCatalogRevision = null;
    _cachedCatalogBody = null;
    _catalogItems = const [];
    _mediaById = const {};
    _clientSockets.clear();
    _clientLastHeartbeat.clear();

    final router = shelf_router.Router()
      ..get('/assets/images/<name>', (shelf.Request r, String name) async {
        _addLog('GET /assets/images/$name');
        if (name.contains('/') || name.contains(r'\') || name.contains('..')) {
          return shelf.Response.forbidden('Invalid asset name');
        }
        try {
          final data = await rootBundle.load('assets/images/$name');
          final bytes = data.buffer.asUint8List();
          final ct = (name.endsWith('.jpg') || name.endsWith('.jpeg'))
              ? 'image/jpeg'
              : 'image/png';
          return shelf.Response.ok(
            bytes,
            headers: {
              'Content-Type': ct,
              'Cache-Control': 'public, max-age=86400',
            },
          );
        } catch (_) {
          return shelf.Response.notFound('Asset not found');
        }
      })
      ..get('/assets/fonts/<name>', (shelf.Request r, String name) async {
        final asset = _browserFontAssets[name];
        if (asset == null) return shelf.Response.notFound('Font not found');
        try {
          final data = await rootBundle.load(asset);
          return shelf.Response.ok(
            data.buffer.asUint8List(),
            headers: {
              'Content-Type': 'font/ttf',
              'Cache-Control': 'public, max-age=31536000, immutable',
            },
          );
        } catch (_) {
          return shelf.Response.notFound('Font not found');
        }
      })
      ..get('/', (_) {
        _addLog('GET / [WEB_UI]');
        return shelf.Response.ok(
          kWebInterfaceHtml,
          headers: {
            'content-type': 'text/html; charset=utf-8',
            'cache-control': 'no-store',
          },
        );
      })
      ..get(
        '/api/health',
        (_) => shelf.Response.ok(
          jsonEncode({
            'ready': _server != null,
            'protocolVersion': 1,
            'catalogRevision': _currentCatalogRevision(),
            'stationRevision': _stationRevision,
            'queueRevision': _queueService.revision,
          }),
          headers: {'content-type': 'application/json'},
        ),
      )
      ..get('/api/media', (shelf.Request request) async {
        final revision = _currentCatalogRevision();
        final etag = '"$revision"';
        if (request.headers['if-none-match'] == etag &&
            _cachedCatalogRevision == revision &&
            _cachedCatalogBody != null) {
          _addLog('GET /api/media [304]');
          return shelf.Response(304, headers: {'etag': etag});
        }
        final body = await _catalogBody(revision);
        final bodyBytes = utf8.encode(body).length;
        _catalogBytesSent += bodyBytes;
        _addLog('GET /api/media bytes=$bodyBytes total=$_catalogBytesSent');
        return shelf.Response.ok(
          body,
          headers: {'content-type': 'application/json', 'etag': etag},
        );
      })
      ..get('/api/stations', (_) async {
        final results = stations.map((s) {
          final state = _stationService.getPlaybackState(s);
          return {...s.toJson(), 'nowPlaying': state?.toJson()};
        }).toList();
        final body = await compute(_jsonEncode, results);
        return shelf.Response.ok(
          body,
          headers: {'content-type': 'application/json'},
        );
      })
      ..get('/api/stations/join/<id>', (shelf.Request r, String id) async {
        final station = stations.firstWhere(
          (s) => s.id == id,
          orElse: () => throw Exception('Station not found'),
        );
        final state = _stationService.getPlaybackState(station);
        if (state == null) return shelf.Response.notFound('No active content');

        // [A3] Master election: first Flutter client to join an active station
        // becomes the sync master (emits sync_state), later joiners slaves.
        // Web clients (no clientId) don't participate.
        // The first joined Flutter client leads station sync. Its playback
        // stop or socket disconnect releases the role for another client.
        var syncRole = '';
        if (station.isActive) {
          final clientId = r.url.queryParameters['clientId'];
          if (clientId != null && clientId.isNotEmpty) {
            _clientStations.putIfAbsent(clientId, () => <String>{}).add(id);
            _stationClients.putIfAbsent(id, () => <String>{}).add(clientId);
            final master = _stationMasters[id];
            if (master == null || master == clientId) {
              _stationMasters[id] = clientId;
              syncRole = 'master';
            } else {
              syncRole = 'slave';
            }
          }
        }

        final response = <String, dynamic>{
          ...state.toJson(),
          'stationRevision': _stationRevision,
          'isPaused': station.isPaused,
          'syncRole': syncRole,
          'playlist': station.playlist
              .map((e) => e.copyWith(isBroadcast: true).toJson())
              .toList(),
        };

        final body = await compute(_jsonEncode, response);
        return shelf.Response.ok(
          body,
          headers: {'content-type': 'application/json'},
        );
      })
      ..get('/api/browse', (shelf.Request r) async {
        final rawPath = r.url.queryParameters['path'] ?? '';

        if (rawPath.isEmpty) {
          final roots = sharedFolders
              .map(
                (f) => {
                  'name': f,
                  'path': f,
                  'isDirectory': true,
                  'itemCount': 0,
                },
              )
              .toList();
          final hasPagination =
              r.url.queryParameters.containsKey('offset') ||
              r.url.queryParameters.containsKey('limit');
          final offset =
              (int.tryParse(r.url.queryParameters['offset'] ?? '0') ?? 0)
                  .clamp(0, roots.length)
                  .toInt();
          final limit =
              (int.tryParse(r.url.queryParameters['limit'] ?? '200') ?? 200)
                  .clamp(1, 500)
                  .toInt();
          final end = (offset + limit).clamp(offset, roots.length).toInt();
          final payload = hasPagination
              ? {
                  'items': roots.sublist(offset, end),
                  'total': roots.length,
                  'offset': offset,
                  'hasMore': end < roots.length,
                }
              : roots;
          final body = await compute(_jsonEncode, payload);
          return shelf.Response.ok(
            body,
            headers: {'content-type': 'application/json'},
          );
        }

        if (!await isPathAllowed(rawPath, sharedFolders)) {
          return shelf.Response.forbidden('Access denied');
        }

        final browseStopwatch = Stopwatch()..start();
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        var hasBrowseSlot = false;
        try {
          if (!await _browseRequestLimiter.acquire(
            timeout: _browseTimeRemaining(deadline),
          )) {
            throw _BrowseCapacityException();
          }
          hasBrowseSlot = true;

          final dir = Directory(Uri.decodeComponent(rawPath));
          if (!await dir.exists().timeout(_browseTimeRemaining(deadline))) {
            return shelf.Response.notFound('Not found');
          }

          final allEntries = await _browseEntries(dir, deadline: deadline);

          final hasPagination =
              r.url.queryParameters.containsKey('offset') ||
              r.url.queryParameters.containsKey('limit');
          final query = r.url.queryParameters['q']?.trim().toLowerCase();
          final sortBy = r.url.queryParameters['sort'] ?? 'name';
          final ascending = r.url.queryParameters['ascending'] != 'false';
          final browseCacheKey = p.normalize(p.absolute(dir.path));
          final browseCache = _browseDirectoryCache[browseCacheKey];
          if (sortBy == 'size' && browseCache?.sizesLoaded != true) {
            await _populateBrowseSizes(allEntries, deadline: deadline);
            if (browseCache != null) browseCache.sizesLoaded = true;
          }
          final filteredEntries = query == null || query.isEmpty
              ? (sortBy == 'name' && ascending
                    ? allEntries
                    : List<Map<String, dynamic>>.of(allEntries))
              : allEntries
                    .where(
                      (entry) => (entry['name'] as String)
                          .toLowerCase()
                          .contains(query),
                    )
                    .toList();
          if (sortBy != 'name' || !ascending) {
            filteredEntries.sort((a, b) {
              final isDirectoryA = a['isDirectory'] == true;
              final isDirectoryB = b['isDirectory'] == true;
              if (isDirectoryA != isDirectoryB) return isDirectoryA ? -1 : 1;
              var comparison = switch (sortBy) {
                'size' => (a['size'] as int).compareTo(b['size'] as int),
                'type' =>
                  p
                      .extension(a['name'] as String)
                      .toLowerCase()
                      .compareTo(
                        p.extension(b['name'] as String).toLowerCase(),
                      ),
                _ => (a['name'] as String).toLowerCase().compareTo(
                  (b['name'] as String).toLowerCase(),
                ),
              };
              if (comparison == 0) {
                comparison = (a['name'] as String).toLowerCase().compareTo(
                  (b['name'] as String).toLowerCase(),
                );
              }
              return ascending ? comparison : -comparison;
            });
          }
          _browseTimeRemaining(deadline);
          final offset =
              (int.tryParse(r.url.queryParameters['offset'] ?? '0') ?? 0)
                  .clamp(0, filteredEntries.length)
                  .toInt();
          final limit = hasPagination
              ? (int.tryParse(r.url.queryParameters['limit'] ?? '200') ?? 200)
                    .clamp(1, 200)
                    .toInt()
              : filteredEntries.length;
          final end = (offset + limit)
              .clamp(offset, filteredEntries.length)
              .toInt();
          final pageEntries = filteredEntries.sublist(offset, end);
          if (sortBy != 'size') {
            await _populateBrowseSizes(pageEntries, deadline: deadline);
          }
          final page = pageEntries.map((entry) {
            final copy = Map<String, dynamic>.from(entry);
            if (copy['size'] == -1) copy['size'] = 0;
            return copy;
          }).toList();

          final payload = hasPagination
              ? {
                  'items': page,
                  'total': filteredEntries.length,
                  'offset': offset,
                  'hasMore': end < filteredEntries.length,
                }
              : page;
          final body = await compute(_jsonEncode, payload);
          _addLog(
            'BROWSE entries=${allEntries.length} returned=${page.length} '
            'elapsed_ms=${browseStopwatch.elapsedMilliseconds}',
          );
          return shelf.Response.ok(
            body,
            headers: {'content-type': 'application/json'},
          );
        } on _BrowseCapacityException {
          return shelf.Response(
            503,
            body: 'Media server is busy. Retry shortly.',
            headers: {'Retry-After': '2'},
          );
        } on TimeoutException {
          _addLog(
            'BROWSE timeout elapsed_ms=${browseStopwatch.elapsedMilliseconds}',
          );
          return shelf.Response(504, body: 'Directory scan timed out');
        } catch (e) {
          return shelf.Response.internalServerError(body: e.toString());
        } finally {
          if (hasBrowseSlot) _browseRequestLimiter.release();
        }
      })
      ..get('/api/file', (shelf.Request r) async {
        final path = r.url.queryParameters['path'] ?? '';
        _addLog('GET /api/file?path=${p.basename(path)}');
        if (path.isEmpty || !await isPathAllowed(path, sharedFolders)) {
          return shelf.Response.forbidden('Access denied');
        }
        return _serveFile(r, File(Uri.decodeComponent(path)));
      })
      ..get('/api/thumbnail/<id>', (shelf.Request r, String id) async {
        final decodedId = Uri.decodeComponent(id);
        return _serveThumbnail(decodedId, sharedFolders);
      })
      ..get('/stream/<id>', (shelf.Request r, String id) async {
        var f = _scanner.fileById(id);
        MediaItem? item;

        if (f == null) {
          final asset = _scanner.assetById(id);
          if (asset != null) f = await asset.file;
          if (f == null) {
            final song = _scanner.songById(id);
            if (song != null) f = File(song.data);
          }
        }

        if (f != null && f.existsSync()) {
          _ensureCatalogIndex(_currentCatalogRevision());
          item = _mediaById[id];

          if (item != null) {
            final connInfo =
                r.context['shelf.io.connection_info'] as HttpConnectionInfo?;
            final ip = connInfo?.remoteAddress.address ?? 'Unknown';

            unawaited(
              _serverRepository.logMediaView(
                HistoryItem(
                  media: item,
                  timestamp: DateTime.now(),
                  clientIp: ip,
                ),
              ),
            );
          }

          return _serveFile(r, f);
        }

        return shelf.Response.notFound('File not found');
      })
      ..get(
        '/ws',
        // [SECURITY B1] Control-plane gate: clients present the pairing token
        // as the WS subprotocol (Sec-WebSocket-Protocol); the server only
        // negotiates that exact protocol. Wrong/missing token => subprotocol
        // is null => rejected with 1008 so clients stop retrying and surface
        // a "pairing required" error instead of reconnecting forever.
        webSocketHandler((WebSocketChannel ws, String? subprotocol) {
          if (pairingToken.isEmpty ||
              !_constantTimeEquals(subprotocol ?? '', pairingToken)) {
            try {
              ws.sink.close(1008, 'pairing required');
            } catch (_) {}
            return;
          }

          if (_sockets.length >= _maxWebSocketClients) {
            try {
              ws.sink.close(4002, 'server at capacity');
            } catch (_) {}
            return;
          }

          _sockets.add(ws);
          _addLog('WS_CONNECT: [ACTIVE: ${_sockets.length}]');
          onSocketsChanged?.call();
          _sendToSocket(ws, {
            'type': 'system',
            'action': 'ready',
            'value': {
              'protocolVersion': 1,
              'catalogRevision': _currentCatalogRevision(),
              'stationRevision': _stationRevision,
              'queueRevision': _queueService.revision,
            },
          });
          _sendToSocket(ws, {
            'type': 'queue',
            'action': 'update',
            'value': _queueSnapshot(),
          });
          final currentVibeColors = _lastVibeColors;
          if (currentVibeColors != null) {
            _sendToSocket(ws, {
              'type': 'system',
              'action': 'vibe_sync',
              'value': currentVibeColors,
            });
          }

          ws.stream.listen(
            (message) {
              var outgoing = message.toString();
              try {
                final data =
                    jsonDecode(message as String) as Map<String, dynamic>;
                if (data['type'] == 'system' && data['action'] == 'heartbeat') {
                  final heartbeat = data['value'];
                  final clientId = heartbeat is Map
                      ? heartbeat['clientId']?.toString()
                      : null;
                  if (clientId != null && clientId.isNotEmpty) {
                    _clientSockets[clientId] = ws;
                    _clientLastHeartbeat[clientId] = DateTime.now();
                  }
                  _sendToSocket(ws, {
                    'type': 'system',
                    'action': 'heartbeat_ack',
                    'value': data['value'],
                  });
                  return;
                }
                // [SECURITY B1] Server-originated commands never arrive over a
                // client socket (the server's own broadcasts are in-process).
                // Any frame claiming senderId 'SERVER' is a forgery — it could
                // lock the queue or trigger SERVER-only actions. Kill the socket.
                if (data['senderId'] == 'SERVER') {
                  try {
                    ws.sink.close(1008, 'impersonation');
                  } catch (_) {}
                  return;
                }
                final senderId =
                    data['clientId']?.toString() ??
                    data['senderId']?.toString();
                if (senderId != null) {
                  _clientSockets[senderId] = ws;
                }

                if (data['type'] == 'media' &&
                    data['action'] == 'sync_state' &&
                    data['value'] is Map) {
                  data['value'] = {
                    ...(data['value'] as Map).cast<String, dynamic>(),
                    'protocolVersion': 1,
                    'stationId': (data['value'] as Map)['stationId'],
                    'stationRevision': _stationRevision,
                    'sequence': ++_syncSequence,
                  };
                  outgoing = jsonEncode(data);
                }

                if (data['type'] == 'report_status') {
                  // [FIX C5] A report with no identity at all used to put a
                  // null key into _activeSessions (TypeError in the WS
                  // listener). Drop unidentifiable frames.
                  final sId =
                      data['sessionId']?.toString() ??
                      data['clientId']?.toString();
                  if (sId == null) return;
                  final stopped = data['isStopped'] == true;
                  if (stopped) {
                    _lastVibeColors = null;
                    _releaseStationMastersForClient(
                      data['clientId']?.toString() ?? sId,
                    );
                    onSessionUpdate?.call(sId, null);
                  } else {
                    final rawProg = data['progress'];
                    final progress = (rawProg is num ? rawProg.toDouble() : 0.0)
                        .clamp(0.0, 1.0)
                        .toDouble();
                    final snapshot = data['snapshot']?.toString();
                    final vibeColors = (data['vibeColors'] as List?)
                        ?.map((e) => e.toString())
                        .toList();
                    final mediaId = data['mediaId']?.toString();
                    final position = data['position'] as int?;

                    if (vibeColors != null &&
                        vibeColors.isNotEmpty &&
                        !listEquals(_lastVibeColors, vibeColors)) {
                      _lastVibeColors = List<String>.unmodifiable(vibeColors);
                      broadcast(
                        jsonEncode({
                          'type': 'system',
                          'action': 'vibe_sync',
                          'value': vibeColors,
                        }),
                      );
                    }

                    onSessionUpdate?.call(
                      sId,
                      StreamSession(
                        sessionId: sId,
                        clientId: data['clientId']?.toString() ?? sId,
                        title: data['title']?.toString() ?? '',
                        mediaId: mediaId,
                        progress: progress,
                        position: position,
                        mediaType: data['mediaType']?.toString() ?? 'video',
                        snapshot: snapshot,
                        vibeColors: vibeColors,
                        lastUpdated: DateTime.now(),
                      ),
                    );
                  }
                  // Status reports update host telemetry only. Relaying every
                  // report to every other client adds O(N²) traffic and no
                  // client consumes these frames.
                  return;
                } else if (data['type'] == 'media' &&
                    data['action'] == 'sync_state') {
                  final syncState = data['value'];
                  final stationId = syncState is Map
                      ? syncState['stationId']?.toString()
                      : null;
                  final subscribers = stationId == null
                      ? null
                      : _stationClients[stationId];
                  if (subscribers != null && subscribers.isNotEmpty) {
                    final sentSockets = <WebSocketChannel>{};
                    for (final clientId in subscribers) {
                      final socket = _clientSockets[clientId];
                      if (socket == null ||
                          identical(socket, ws) ||
                          !sentSockets.add(socket)) {
                        continue;
                      }
                      _sendToSocket(socket, data);
                    }
                    return;
                  }
                  // Keep legacy / not-yet-joined clients working when station
                  // membership is unavailable; subscribed stations avoid the
                  // all-clients fan-out for their periodic sync snapshots.
                  for (final socket in List.of(_sockets)) {
                    if (!identical(socket, ws)) _sendToSocket(socket, data);
                  }
                  return;
                } else if (data['type'] == 'queue') {
                  if (data['action'] == 'add') {
                    _queueService.addItem(
                      MediaItem.fromJson(data['value'] as Map<String, dynamic>),
                      (data['senderId'] ?? 'Unknown').toString(),
                    );
                  } else if (data['action'] == 'vote') {
                    final voteData = data['value'] as Map<String, dynamic>;
                    _queueService.voteItem(
                      voteData['id'] as String,
                      voteData['delta'] as int,
                    );
                  }
                  // NOTE: the old 'lock' action required senderId 'SERVER'
                  // over the wire — i.e. it was only reachable by
                  // impersonation. The impersonation guard above kills that
                  // path, so the branch was removed (server-side locking
                  // should be an in-process API if ever needed).

                  broadcast(
                    jsonEncode({
                      'type': 'queue',
                      'action': 'update',
                      'value': _queueSnapshot(),
                    }),
                  );
                } else if (data['type'] == 'intercom') {
                  broadcast(outgoing);
                } else if (data['targetId'] != null) {
                  final targetId = data['targetId'].toString();
                  final targetSocket = _clientSockets[targetId];

                  if (targetSocket != null) {
                    try {
                      targetSocket.sink.add(outgoing);
                    } catch (e) {
                      logger.w(
                        'Failed to send targeted message to $targetId',
                        error: e,
                      );
                      _clientSockets.remove(targetId);
                    }
                  } else {
                    for (final s in List.of(_sockets)) {
                      if (s != ws) {
                        try {
                          s.sink.add(outgoing);
                        } catch (_) {}
                      }
                    }
                  }
                } else {
                  for (final s in List.of(_sockets)) {
                    if (s != ws) {
                      try {
                        s.sink.add(outgoing);
                      } catch (_) {}
                    }
                  }
                }
              } catch (_) {
                for (final s in List.of(_sockets)) {
                  if (s != ws) {
                    try {
                      s.sink.add(outgoing);
                    } catch (_) {}
                  }
                }
              }
            },
            onDone: () {
              _releaseSocket(ws);
            },
            onError: (_) {
              _releaseSocket(ws, error: true);
            },
            cancelOnError: false,
          );
        }, protocols: pairingToken.isNotEmpty ? {pairingToken} : <String>{}),
      );

    // Middleware: CORS + connection tracking.
    shelf.Handler withMiddleware(shelf.Handler inner) =>
        (shelf.Request request) async {
          if (request.method == 'OPTIONS') {
            return shelf.Response.ok('', headers: _corsHeaders);
          }
          final connInfo =
              request.context['shelf.io.connection_info']
                  as HttpConnectionInfo?;
          if (connInfo != null) {
            final remoteIp = connInfo.remoteAddress.address;
            // Skip localhost to avoid log spam from internal previews.
            if (remoteIp != '127.0.0.1' && remoteIp != '::1') {
              onConnection?.call(remoteIp);
            }
          }
          final response = await inner(request);
          return response.change(headers: _corsHeaders);
        };

    final handler = const shelf.Pipeline()
        .addMiddleware(withMiddleware)
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = Timer.periodic(
      _heartbeatSweepInterval,
      (_) => _expireUnresponsiveClients(),
    );
    logger.i('[HttpServer] Listening on http://$ip:8080');
  }

  Future<void> stop() async {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = null;
    await _server?.close(force: true);
    _server = null;
    _logNotifyTimer?.cancel();
    _logNotifyTimer = null;
    _lastVibeColors = null;
    _catalogItems = const [];
    _mediaById = const {};
    _cachedCatalogRevision = null;
    _cachedCatalogBody = null;
    _catalogBuild = null;
    _cachedQueueSnapshot = null;
    _cachedQueueRevision = null;
    _browseCacheGeneration++;
    _browseDirectoryCache.clear();
    _browseLoads.clear();
    // Close all open WebSocket connections gracefully.
    for (final s in List.of(_sockets)) {
      try {
        await s.sink.close();
      } catch (_) {}
    }
    _sockets.clear();
    _clientSockets.clear();
    _clientLastHeartbeat.clear();
    _clientStations.clear();
    _stationClients.clear();
    _stationMasters.clear();
    _getMediaItems = null;
    _getMediaRevision = null;
    onSocketsChanged?.call();
    logger.i('[HttpServer] Stopped');
  }

  void broadcast(String message) {
    for (final s in List.of(_sockets)) {
      try {
        s.sink.add(message);
      } catch (_) {}
    }
  }

  /// Called when a station is (re)activated or removed so the next joiner
  /// can be re-elected as sync master.
  void clearStationMaster(String stationId) {
    _stationMasters.remove(stationId);
    final clients = _stationClients.remove(stationId) ?? const <String>{};
    for (final clientId in clients) {
      final stationIds = _clientStations[clientId];
      stationIds?.remove(stationId);
      if (stationIds?.isEmpty == true) _clientStations.remove(clientId);
    }
  }

  Future<String> _catalogBody(String revision) async {
    while (true) {
      if (_cachedCatalogRevision == revision && _cachedCatalogBody != null) {
        return _cachedCatalogBody!;
      }
      final pending = _catalogBuild;
      if (pending != null) {
        await pending;
        continue;
      }
      final build = _buildCatalog(revision);
      _catalogBuild = build;
      try {
        return await build;
      } finally {
        if (identical(_catalogBuild, build)) _catalogBuild = null;
      }
    }
  }

  String _currentCatalogRevision() =>
      '$_catalogEpoch:${_getMediaRevision?.call() ?? '0'}';

  Future<String> _buildCatalog(String revision) async {
    _ensureCatalogIndex(revision);
    final body = await compute(
      _jsonEncode,
      _catalogItems.map((item) => item.toJson()).toList(),
    );
    if (_cachedCatalogRevision == revision) _cachedCatalogBody = body;
    return body;
  }

  void _ensureCatalogIndex(String revision) {
    if (_cachedCatalogRevision == revision) return;
    _catalogItems = _getMediaItems?.call() ?? const [];
    _mediaById = {for (final item in _catalogItems) item.id: item};
    _cachedCatalogRevision = revision;
    _cachedCatalogBody = null;
  }

  Map<String, dynamic> _queueSnapshot() {
    final revision = _queueService.revision;
    if (_cachedQueueRevision != revision || _cachedQueueSnapshot == null) {
      _cachedQueueSnapshot = _queueService.queue
          .map((item) => item.toJson())
          .toList(growable: false);
      _cachedQueueRevision = revision;
    }
    return {
      'items': _cachedQueueSnapshot,
      'isLocked': _queueService.isLocked,
      'revision': revision,
    };
  }

  Future<List<Map<String, dynamic>>> _browseEntries(
    Directory directory, {
    required DateTime deadline,
  }) async {
    final key = p.normalize(p.absolute(directory.path));
    final cached = _browseDirectoryCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(seconds: 20)) {
      return cached.entries;
    }
    final pending = _browseLoads[key];
    if (pending != null) return pending.timeout(_browseTimeRemaining(deadline));

    final load = _readBrowseEntries(directory, deadline: deadline);
    _browseLoads[key] = load;
    final generation = _browseCacheGeneration;
    try {
      final entries = await load;
      if (generation != _browseCacheGeneration ||
          entries.length > _maxCachedBrowseEntries) {
        return entries;
      }
      if (_browseDirectoryCache.length >= _maxCachedBrowseDirectories) {
        _browseDirectoryCache.remove(_browseDirectoryCache.keys.first);
      }
      _browseDirectoryCache[key] = _BrowseDirectoryCache(
        DateTime.now(),
        entries,
      );
      return entries;
    } finally {
      if (identical(_browseLoads[key], load)) {
        unawaited(_browseLoads.remove(key));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _readBrowseEntries(
    Directory directory, {
    required DateTime deadline,
  }) async {
    final entries = <Map<String, dynamic>>[];
    await for (final entity
        in directory
            .list(followLinks: false)
            .timeout(_browseTimeRemaining(deadline))) {
      _browseTimeRemaining(deadline);
      final name = entity.uri.pathSegments.lastWhere(
        (segment) => segment.isNotEmpty,
        orElse: () => entity.path,
      );
      entries.add({
        'name': name,
        'path': entity.path,
        'isDirectory': entity is Directory,
        'size': entity is Directory ? 0 : -1,
        'itemCount': 0,
      });
    }
    entries.sort((a, b) {
      if (a['isDirectory'] == true && b['isDirectory'] != true) return -1;
      if (a['isDirectory'] != true && b['isDirectory'] == true) return 1;
      return (a['name'] as String).toLowerCase().compareTo(
        (b['name'] as String).toLowerCase(),
      );
    });
    return entries;
  }

  Future<void> _populateBrowseSizes(
    List<Map<String, dynamic>> entries, {
    required DateTime deadline,
  }) async {
    for (var start = 0; start < entries.length; start += 32) {
      final end = (start + 32).clamp(start, entries.length).toInt();
      await Future.wait(
        entries.sublist(start, end).map((entry) async {
          if (entry['isDirectory'] == true || entry['size'] != -1) return;
          try {
            entry['size'] = await File(
              entry['path'] as String,
            ).length().timeout(_browseTimeRemaining(deadline));
          } on TimeoutException {
            rethrow;
          } catch (_) {
            entry['size'] = 0;
          }
        }),
      ).timeout(_browseTimeRemaining(deadline));
    }
  }

  Duration _browseTimeRemaining(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TimeoutException('Directory scan timed out');
    }
    return remaining;
  }

  void _sendToSocket(WebSocketChannel socket, Map<String, dynamic> message) {
    try {
      socket.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  void _releaseSocket(WebSocketChannel socket, {bool error = false}) {
    final wasTracked = _sockets.remove(socket);
    final disconnectedIds = _clientSockets.entries
        .where((entry) => identical(entry.value, socket))
        .map((entry) => entry.key)
        .toSet();
    if (!wasTracked && disconnectedIds.isEmpty) return;
    _clientSockets.removeWhere(
      (_, connectedSocket) => identical(connectedSocket, socket),
    );
    _clientLastHeartbeat.removeWhere((id, _) => disconnectedIds.contains(id));
    for (final id in disconnectedIds) {
      _releaseStationMastersForClient(id);
    }

    _addLog(
      '${error ? 'WS_ERROR' : 'WS_DISCONNECT'}: [ACTIVE: ${_sockets.length}]',
    );
    onSocketsChanged?.call();
  }

  @visibleForTesting
  void expireUnresponsiveClientsAt(DateTime now) =>
      _expireUnresponsiveClients(now);

  void _expireUnresponsiveClients([DateTime? currentTime]) {
    final now = currentTime ?? DateTime.now();
    final staleClientIds = _clientLastHeartbeat.entries
        .where((entry) => hasHeartbeatExpired(entry.value, now))
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final clientId in staleClientIds) {
      final socket = _clientSockets.remove(clientId);
      _clientLastHeartbeat.remove(clientId);
      _releaseStationMastersForClient(clientId);
      _addLog('WS_HEARTBEAT_TIMEOUT: $clientId');

      if (socket == null) continue;
      final hasAnotherLiveClient = _clientLastHeartbeat.entries.any(
        (entry) =>
            identical(_clientSockets[entry.key], socket) &&
            !hasHeartbeatExpired(entry.value, now),
      );
      if (hasAnotherLiveClient) continue;

      try {
        unawaited(
          socket.sink.close(4001, 'heartbeat timeout').catchError((
            Object error,
          ) {
            logger.w('WebSocket heartbeat close failed', error: error);
          }),
        );
      } catch (_) {}
      _releaseSocket(socket, error: true);
    }
  }

  void _releaseStationMastersForClient(String clientId) {
    final stationIds = _clientStations.remove(clientId);
    if (stationIds == null) return;
    for (final stationId in stationIds) {
      final subscribers = _stationClients[stationId];
      subscribers?.remove(clientId);
      if (subscribers?.isEmpty == true) _stationClients.remove(stationId);
      if (_stationMasters[stationId] != clientId) continue;
      _stationMasters.remove(stationId);
      BroadcastStation? station;
      for (final item in _stations) {
        if (item.id == stationId) {
          station = item;
          break;
        }
      }
      if (station == null) continue;
      broadcast(
        jsonEncode({
          'type': 'system',
          'action': 'sync_master_available',
          'value': {
            'stationId': stationId,
            'mediaIds': station.playlist.map((item) => item.id).toList(),
          },
        }),
      );
    }
  }

  // ── File Serving ──────────────────────────────────────────────────────────

  /// [FIX C1] Parse + clamp a `Range: bytes=a-b` header against [fileSize].
  /// Returns (start, end) for a 206, or null when unsatisfiable (416) —
  /// including the empty-file case, where clamp(0, fileSize - 1) used to
  /// throw RangeError(0, -1) and 500 the request.
  static (int, int)? parseRange(String header, int fileSize) {
    if (fileSize == 0) return null;
    final parts = header.replaceFirst('bytes=', '').split('-');
    final start = (int.tryParse(parts[0]) ?? 0).clamp(0, fileSize - 1).toInt();
    // FIX: clamp end to fileSize - 1 to prevent out-of-range reads.
    final end = (parts.length > 1 && parts[1].isNotEmpty)
        ? (int.tryParse(parts[1]) ?? (fileSize - 1))
              .clamp(start, fileSize - 1)
              .toInt()
        : fileSize - 1;
    if (end - start + 1 <= 0) return null;
    return (start, end);
  }

  Future<shelf.Response> _serveFile(shelf.Request r, File file) async {
    if (!await file.exists()) return shelf.Response.notFound('Not found');
    final stat = await file.stat();
    final fileSize = stat.size;
    final ct = FileTypeUtils.contentType(file.path);
    final rangeHeader = r.headers['range'];
    int? start;
    int? end;
    if (rangeHeader != null) {
      final bounds = parseRange(rangeHeader, fileSize);
      if (bounds == null) {
        return shelf.Response(
          416,
          headers: {'Content-Range': 'bytes */$fileSize', 'Content-Type': ct},
        );
      }
      (start, end) = bounds;
    }

    if (_activeStreams >= _maxConcurrentStreams) {
      return shelf.Response(
        503,
        body: 'Media server is busy. Retry shortly.',
        headers: {'Retry-After': '2'},
      );
    }
    _activeStreams++;
    _addLog('STREAM_OPEN: [ACTIVE: $_activeStreams]');

    if (rangeHeader != null) {
      final rangeStart = start!;
      final rangeEnd = end!;
      final length = rangeEnd - rangeStart + 1;

      return shelf.Response(
        206,
        body: _tracked(file.openRead(rangeStart, rangeEnd + 1)),
        headers: {
          'Content-Type': ct,
          'Content-Range': 'bytes $rangeStart-$rangeEnd/$fileSize',
          'Content-Length': '$length',
          'Accept-Ranges': 'bytes',
        },
      );
    }

    return shelf.Response.ok(
      _tracked(file.openRead()),
      headers: {
        'Content-Type': ct,
        'Content-Length': '$fileSize',
        'Accept-Ranges': 'bytes',
      },
    );
  }

  Stream<List<int>> _tracked(Stream<List<int>> src) async* {
    try {
      await for (final chunk in src) {
        _totalBytesSent += chunk.length;
        yield chunk;
      }
    } finally {
      _activeStreams = (_activeStreams - 1)
          .clamp(0, _maxConcurrentStreams)
          .toInt();
      _addLog('STREAM_CLOSE: [ACTIVE: $_activeStreams]');
    }
  }

  static String _jsonEncode(dynamic data) => jsonEncode(data);

  // ── Thumbnail Serving ──────────────────────────────────────────────────────

  Future<shelf.Response> _serveThumbnail(
    String id,
    List<String> sharedFolders,
  ) async {
    var cacheKey = 'thumbnail_v2:$id';
    final file = _scanner.fileById(id);

    // If it's a local file, incorporate the modification timestamp into the cache key.
    // This ensures that if a file is replaced, a new thumbnail is generated.
    try {
      final targetFile = file ?? File(id);
      if (await targetFile.exists()) {
        final stat = await targetFile.stat();
        cacheKey = 'thumbnail_v2:${id}_${stat.modified.millisecondsSinceEpoch}';
      }
    } catch (_) {}

    final pending = _thumbnailLoads[cacheKey];
    if (pending != null) return pending;

    final response = _loadThumbnail(id, cacheKey, file, sharedFolders);
    _thumbnailLoads[cacheKey] = response;
    try {
      return await response;
    } finally {
      if (identical(_thumbnailLoads[cacheKey], response)) {
        _thumbnailLoads.remove(cacheKey);
      }
    }
  }

  Future<shelf.Response> _loadThumbnail(
    String id,
    String cacheKey,
    File? file,
    List<String> sharedFolders,
  ) async {
    // Check disk cache first.
    final cached = await _thumbCache.get(cacheKey);
    if (cached != null) {
      return shelf.Response.ok(
        cached,
        headers: {
          'Content-Type': _detectImageType(cached),
          'Cache-Control': 'public, max-age=86400',
        },
      );
    }

    Uint8List? data;

    // 1. PhotoManager asset (Android/iOS/macOS photo library).
    final asset = _scanner.assetById(id);
    if (asset != null) {
      data = await asset.thumbnailDataWithSize(const ThumbnailSize(400, 400));
    }

    // 2. Audio artwork (Android/iOS).
    if (data == null &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final song = _scanner.songById(id) ?? _scanner.songByPath(id);
      if (song != null) {
        data = await OnAudioQuery().queryArtwork(
          song.id,
          ArtworkType.AUDIO,
          size: 400,
        );
      }
    }

    // 3. Video thumbnail via robust cross-platform generator.
    if (data == null && !kIsWeb) {
      // The id may be either a scanner ID or a raw file path.
      final filePath = file?.path ?? id;
      if (await isPathAllowed(filePath, sharedFolders) &&
          await File(filePath).exists()) {
        final type = FileTypeUtils.fromFilename(filePath);
        if (type == MediaFileType.video) {
          data = await _thumbGenerator.generateThumbnail(
            filePath,
            maxWidth: 400,
            quality: 85,
          );
        } else if (type == MediaFileType.image) {
          // Keep image-card transfers bounded instead of sending full-resolution
          // originals. Flutter's codec downsamples during decode and preserves
          // the source aspect ratio; unsupported formats retain their original.
          data = await _resizeImageThumbnail(
            await File(filePath).readAsBytes(),
          );
        }
      }
    }

    if (data != null) {
      await _thumbCache.put(cacheKey, data);
      final ct = _detectImageType(data);
      return shelf.Response.ok(
        data,
        headers: {'Content-Type': ct, 'Cache-Control': 'public, max-age=86400'},
      );
    }

    return shelf.Response.notFound('No thumbnail');
  }

  Future<Uint8List> _resizeImageThumbnail(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodecWithSize(
        await ui.ImmutableBuffer.fromUint8List(bytes),
        getTargetSize: (width, height) => width >= height
            ? ui.TargetImageSize(width: width.clamp(1, 400).toInt())
            : ui.TargetImageSize(height: height.clamp(1, 400).toInt()),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return bytes;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return bytes;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  String _detectImageType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };
}
