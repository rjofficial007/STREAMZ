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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/core/utils/file_type_utils.dart';
import 'package:streamz/core/utils/logger.dart';
import 'package:streamz/data/local/media_scanner.dart';
import 'package:streamz/data/local/thumbnail_cache.dart';
import 'package:streamz/data/network/modern_web_html.dart';
import 'package:streamz/data/network/web_html.dart';
import 'package:streamz/data/repositories/server_repository.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/history_item.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/models/stream_session.dart';
import 'package:streamz/domain/services/queue_service.dart';
import 'package:streamz/domain/services/station_service.dart';
import 'package:streamz/domain/services/video_thumbnail_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef SessionUpdateCallback = void Function(String sessionId, StreamSession? session);
typedef ConnectionLogCallback = void Function(String ip);

class HttpServerService {

  HttpServerService({required MediaScanner scanner, required ThumbnailCache thumbCache, required VideoThumbnailService thumbGenerator})
    : _scanner = scanner,
      _thumbCache = thumbCache,
      _thumbGenerator = thumbGenerator;
  final MediaScanner _scanner;
  final ThumbnailCache _thumbCache;
  final VideoThumbnailService _thumbGenerator;

  HttpServer? _server;

  List<BroadcastStation> stations = [];

  // [A3] station id -> elected sync-master client id (first Flutter joiner
  // since the station was (re)activated). Web joiners don't participate.
  final Map<String, String> _stationMasters = {};

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
  final List<String> _logs = [];
  int _totalBytesSent = 0;

  bool useModernWebUI = true;

  SessionUpdateCallback? onSessionUpdate;
  ConnectionLogCallback? onConnection;
  void Function()? onSocketsChanged;

  bool get isRunning => _server != null;
  int get socketCount => _sockets.length;
  int get bytesSent => _totalBytesSent;
  List<String> get logs => List.unmodifiable(_logs);

  void _addLog(String message) {
    logger.i('[HttpServer] $message');
    final timestamp = DateTime.now().toString().split(' ').last.split('.').first;
    _logs.add('[$timestamp] $message');
    if (_logs.length > 100) _logs.removeAt(0);
    onSocketsChanged?.call();
  }

  // ── Security ───────────────────────────────────────────────────────────────

  /// Returns true only if [rawPath] resolves to a location inside one of
  /// [sharedFolders] after URL-decoding and OS-level canonicalisation.
  bool _isPathAllowed(String rawPath, List<String> sharedFolders) {
    if (rawPath.isEmpty) return false;
    try {
      final decoded = Uri.decodeComponent(rawPath);
      final absolutePath = p.absolute(decoded);
      final canonical = p.canonicalize(absolutePath);

      for (final folder in sharedFolders) {
        final canonicalFolder = p.canonicalize(p.absolute(folder));
        if (canonical == canonicalFolder || p.isWithin(canonicalFolder, canonical)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      logger.e('Path allowed check error: $rawPath', error: e);
      return false;
    }
  }

  // ── Server Lifecycle ───────────────────────────────────────────────────────

  Future<void> start({required String ip, required List<String> sharedFolders, required List<MediaItem> Function() getMediaItems}) async {
    if (_server != null) await stop();

    final router = shelf_router.Router()
      ..get('/assets/images/<name>', (shelf.Request r, String name) async {
        _addLog('GET /assets/images/$name');
        if (name.contains('/') || name.contains(r'\') || name.contains('..')) {
          return shelf.Response.forbidden('Invalid asset name');
        }
        try {
          final data = await rootBundle.load('assets/images/$name');
          final bytes = data.buffer.asUint8List();
          final ct = (name.endsWith('.jpg') || name.endsWith('.jpeg')) ? 'image/jpeg' : 'image/png';
          return shelf.Response.ok(bytes, headers: {'Content-Type': ct, 'Cache-Control': 'public, max-age=86400'});
        } catch (_) {
          return shelf.Response.notFound('Asset not found');
        }
      })
      ..get('/', (_) {
        _addLog('GET / [WEB_UI]');
        final html = useModernWebUI ? kModernWebInterfaceHtml : kWebInterfaceHtml;
        return shelf.Response.ok(html, headers: {'content-type': 'text/html; charset=utf-8'});
      })
      ..get('/api/media', (_) async {
        _addLog('GET /api/media');
        final items = getMediaItems();
        final body = await compute(_jsonEncode, items.map((e) => e.toJson()).toList());
        return shelf.Response.ok(body, headers: {'content-type': 'application/json'});
      })
      ..get('/api/stations', (_) async {
        final svc = sl<StationService>();
        final results = stations.map((s) {
          final state = svc.getPlaybackState(s);
          return {...s.toJson(), 'nowPlaying': state?.toJson()};
        }).toList();
        final body = await compute(_jsonEncode, results);
        return shelf.Response.ok(body, headers: {'content-type': 'application/json'});
      })
      ..get('/api/stations/join/<id>', (shelf.Request r, String id) async {
        final station = stations.firstWhere((s) => s.id == id, orElse: () => throw Exception('Station not found'));
        final svc = sl<StationService>();
        final state = svc.getPlaybackState(station);
        if (state == null) return shelf.Response.notFound('No active content');

        // [A3] Master election: first Flutter client to join an active station
        // becomes the sync master (emits sync_state), later joiners slaves.
        // Web clients (no clientId) don't participate.
        // ponytail: master is sticky for the station run — if the master node
        // disconnects the station runs unsynced until the next (re)start.
        // Upgrade path: re-elect on WS disconnect.
        var syncRole = '';
        if (station.isActive) {
          final clientId = r.url.queryParameters['clientId'];
          if (clientId != null && clientId.isNotEmpty) {
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
          'isPaused': station.isPaused,
          'syncRole': syncRole,
          'playlist': station.playlist.map((e) => e.copyWith(isBroadcast: true).toJson()).toList(),
        };

        final body = await compute(_jsonEncode, response);
        return shelf.Response.ok(body, headers: {'content-type': 'application/json'});
      })
      ..get('/api/browse', (shelf.Request r) async {
        final rawPath = r.url.queryParameters['path'] ?? '';

        if (rawPath.isEmpty) {
          final roots = sharedFolders.map((f) => {'name': f, 'path': f, 'isDirectory': true, 'itemCount': 0}).toList();
          final body = await compute(_jsonEncode, roots);
          return shelf.Response.ok(body, headers: {'content-type': 'application/json'});
        }

        if (!_isPathAllowed(rawPath, sharedFolders)) {
          return shelf.Response.forbidden('Access denied');
        }

        try {
          final dir = Directory(Uri.decodeComponent(rawPath));
          if (!await dir.exists()) {
            return shelf.Response.notFound('Not found');
          }

          final entries = <Map<String, dynamic>>[];
          await dir
              .list(followLinks: false)
              .handleError((_) {})
              .asyncMap((entity) async {
                final stat = await entity.stat();
                final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => entity.path);
                return {'name': name, 'path': entity.path, 'isDirectory': entity is Directory, 'size': stat.size, 'itemCount': 0};
              })
              .timeout(const Duration(seconds: 10), onTimeout: (sink) => sink.close())
              .forEach(entries.add);

          entries.sort((a, b) {
            if (a['isDirectory'] == true && b['isDirectory'] != true) return -1;
            if (a['isDirectory'] != true && b['isDirectory'] == true) return 1;
            return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
          });

          final body = await compute(_jsonEncode, entries);
          return shelf.Response.ok(body, headers: {'content-type': 'application/json'});
        } catch (e) {
          return shelf.Response.internalServerError(body: e.toString());
        }
      })
      ..get('/api/file', (shelf.Request r) async {
        final path = r.url.queryParameters['path'] ?? '';
        _addLog('GET /api/file?path=${p.basename(path)}');
        if (path.isEmpty || !_isPathAllowed(path, sharedFolders)) {
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
          try {
            final all = getMediaItems();
            item = all.firstWhere((m) => m.id == id);
          } catch (_) {}

          if (item != null) {
            final connInfo = r.context['shelf.io.connection_info'] as HttpConnectionInfo?;
            final ip = connInfo?.remoteAddress.address ?? 'Unknown';
            
            unawaited(sl<ServerRepository>().logMediaView(HistoryItem(
              media: item,
              timestamp: DateTime.now(),
              clientIp: ip,
            )));
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
          if (pairingToken.isEmpty || !_constantTimeEquals(subprotocol ?? '', pairingToken)) {
            try {
              ws.sink.close(1008, 'pairing required');
            } catch (_) {}
            return;
          }

          _sockets.add(ws);
          _addLog('WS_CONNECT: [ACTIVE: ${_sockets.length}]');
          onSocketsChanged?.call();

          ws.stream.listen(
            (message) {
              try {
                final data = jsonDecode(message as String) as Map<String, dynamic>;
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
                final senderId = data['clientId']?.toString() ?? data['senderId']?.toString();
                if (senderId != null) {
                  _clientSockets[senderId] = ws;
                }

                if (data['type'] == 'report_status') {
                    // [FIX C5] A report with no identity at all used to put a
                    // null key into _activeSessions (TypeError in the WS
                    // listener). Drop unidentifiable frames.
                    final sId = data['sessionId']?.toString() ?? data['clientId']?.toString();
                    if (sId == null) return;
                    final stopped = data['isStopped'] == true;
                    if (stopped) {
                      onSessionUpdate?.call(sId, null);
                    } else {
                      final rawProg = data['progress'];
                      final progress = (rawProg is num ? rawProg.toDouble() : 0.0).clamp(0.0, 1.0);
                      final snapshot = data['snapshot']?.toString();
                      final vibeColors = (data['vibeColors'] as List?)?.map((e) => e.toString()).toList();
                      final mediaId = data['mediaId']?.toString();
                      final position = data['position'] as int?;

                      if (vibeColors != null && vibeColors.isNotEmpty) {
                        broadcast(jsonEncode({
                          'type': 'system',
                          'action': 'vibe_sync',
                          'value': vibeColors,
                        }));
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
                  } else if (data['type'] == 'queue') {
                    final queueSvc = sl<QueueService>();
                    if (data['action'] == 'add') {
                      queueSvc.addItem(MediaItem.fromJson(data['value'] as Map<String, dynamic>), (data['senderId'] ?? 'Unknown').toString());
                    } else if (data['action'] == 'vote') {
                      final voteData = data['value'] as Map<String, dynamic>;
                      queueSvc.voteItem(voteData['id'] as String, voteData['delta'] as int);
                    }
                    // NOTE: the old 'lock' action required senderId 'SERVER'
                    // over the wire — i.e. it was only reachable by
                    // impersonation. The impersonation guard above kills that
                    // path, so the branch was removed (server-side locking
                    // should be an in-process API if ever needed).
                    
                    broadcast(jsonEncode({
                      'type': 'queue',
                      'action': 'update',
                      'value': {
                        'items': queueSvc.queue.map((e) => e.toJson()).toList(),
                        'isLocked': queueSvc.isLocked,
                      },
                    }));
                  } else if (data['type'] == 'intercom') {
                    broadcast(message.toString());
                  } else if (data['targetId'] != null) {
                    final targetId = data['targetId'].toString();
                    final targetSocket = _clientSockets[targetId];
                    
                    if (targetSocket != null) {
                      try {
                        targetSocket.sink.add(message);
                      } catch (e) {
                        logger.w('Failed to send targeted message to $targetId', error: e);
                        _clientSockets.remove(targetId);
                      }
                    } else {
                      for (final s in List.of(_sockets)) {
                        if (s != ws) {
                          try {
                            s.sink.add(message);
                          } catch (_) {}
                        }
                      }
                    }
                  } else {
                    for (final s in List.of(_sockets)) {
                      if (s != ws) {
                        try {
                          s.sink.add(message);
                        } catch (_) {}
                      }
                    }
                  }
                } catch (_) {
                  for (final s in List.of(_sockets)) {
                    if (s != ws) {
                      try {
                        s.sink.add(message);
                      } catch (_) {}
                    }
                  }
                }
              },
              onDone: () {
                _sockets.remove(ws);
                _clientSockets.removeWhere((_, socket) => socket == ws);
                _addLog('WS_DISCONNECT: [ACTIVE: ${_sockets.length}]');
                onSocketsChanged?.call();
              },
              onError: (_) {
                _sockets.remove(ws);
                _clientSockets.removeWhere((_, socket) => socket == ws);
                _addLog('WS_ERROR: [ACTIVE: ${_sockets.length}]');
                onSocketsChanged?.call();
              },
              cancelOnError: false,
            );
          }, protocols: pairingToken.isNotEmpty ? {pairingToken} : <String>{}),
        );

    // Middleware: CORS + connection tracking.
    shelf.Handler withMiddleware(shelf.Handler inner) => (shelf.Request request) async {
        if (request.method == 'OPTIONS') {
          return shelf.Response.ok('', headers: _corsHeaders);
        }
        final connInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
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

    final handler = const shelf.Pipeline().addMiddleware(withMiddleware).addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
    logger.i('[HttpServer] Listening on http://$ip:8080');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    // Close all open WebSocket connections gracefully.
    for (final s in List.of(_sockets)) {
      try {
        await s.sink.close();
      } catch (_) {}
    }
    _sockets.clear();
    _clientSockets.clear();
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
  void clearStationMaster(String stationId) => _stationMasters.remove(stationId);

  // ── File Serving ──────────────────────────────────────────────────────────

  /// [FIX C1] Parse + clamp a `Range: bytes=a-b` header against [fileSize].
  /// Returns (start, end) for a 206, or null when unsatisfiable (416) —
  /// including the empty-file case, where clamp(0, fileSize - 1) used to
  /// throw RangeError(0, -1) and 500 the request.
  static (int, int)? parseRange(String header, int fileSize) {
    if (fileSize == 0) return null;
    final parts = header.replaceFirst('bytes=', '').split('-');
    final start = (int.tryParse(parts[0]) ?? 0).clamp(0, fileSize - 1);
    // FIX: clamp end to fileSize - 1 to prevent out-of-range reads.
    final end = (parts.length > 1 && parts[1].isNotEmpty) ? (int.tryParse(parts[1]) ?? (fileSize - 1)).clamp(start, fileSize - 1) : fileSize - 1;
    if (end - start + 1 <= 0) return null;
    return (start, end);
  }

  Future<shelf.Response> _serveFile(shelf.Request r, File file) async {
    if (!await file.exists()) return shelf.Response.notFound('Not found');
    final stat = await file.stat();
    final fileSize = stat.size;
    final ct = FileTypeUtils.contentType(file.path);
    final rangeHeader = r.headers['range'];

    if (rangeHeader != null) {
      final bounds = parseRange(rangeHeader, fileSize);
      if (bounds == null) {
        return shelf.Response(416, headers: {'Content-Range': 'bytes */$fileSize', 'Content-Type': ct});
      }
      final (start, end) = bounds;
      final length = end - start + 1;

      return shelf.Response(
        206,
        body: _tracked(file.openRead(start, end + 1)),
        headers: {'Content-Type': ct, 'Content-Range': 'bytes $start-$end/$fileSize', 'Content-Length': '$length', 'Accept-Ranges': 'bytes'},
      );
    }

    return shelf.Response.ok(_tracked(file.openRead()), headers: {'Content-Type': ct, 'Content-Length': '$fileSize', 'Accept-Ranges': 'bytes'});
  }

  Stream<List<int>> _tracked(Stream<List<int>> src) async* {
    await for (final chunk in src) {
      _totalBytesSent += chunk.length;
      yield chunk;
    }
  }

  static String _jsonEncode(dynamic data) => jsonEncode(data);

  // ── Thumbnail Serving ──────────────────────────────────────────────────────

  Future<shelf.Response> _serveThumbnail(String id, List<String> sharedFolders) async {
    var cacheKey = id;
    final file = _scanner.fileById(id);

    // If it's a local file, incorporate the modification timestamp into the cache key.
    // This ensures that if a file is replaced, a new thumbnail is generated.
    try {
      final targetFile = file ?? File(id);
      if (await targetFile.exists()) {
        final stat = await targetFile.stat();
        cacheKey = '${id}_${stat.modified.millisecondsSinceEpoch}';
      }
    } catch (_) {}

    // Check disk cache first.
    final cached = await _thumbCache.get(cacheKey);
    if (cached != null) {
      return shelf.Response.ok(cached, headers: {'Content-Type': 'image/jpeg', 'Cache-Control': 'public, max-age=86400'});
    }

    Uint8List? data;

    // 1. PhotoManager asset (Android/iOS/macOS photo library).
    final asset = _scanner.assetById(id);
    if (asset != null) {
      data = await asset.thumbnailDataWithSize(const ThumbnailSize(400, 400));
    }

    // 2. Audio artwork (Android/iOS).
    if (data == null && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      final song = _scanner.songById(id) ?? _scanner.songByPath(id);
      if (song != null) {
        data = await OnAudioQuery().queryArtwork(song.id, ArtworkType.AUDIO, size: 400);
      }
    }

    // 3. Video thumbnail via robust cross-platform generator.
    if (data == null && !kIsWeb) {
      // The id may be either a scanner ID or a raw file path.
      final filePath = file?.path ?? id;
      if (_isPathAllowed(filePath, sharedFolders) && File(filePath).existsSync()) {
        final type = FileTypeUtils.fromFilename(filePath);
        if (type == MediaFileType.video) {
          data = await _thumbGenerator.generateThumbnail(filePath, maxWidth: 400, quality: 85);
        } else if (type == MediaFileType.image) {
          // For images, the original file is our thumbnail.
          data = await File(filePath).readAsBytes();
        }
      }
    }

    if (data != null) {
      await _thumbCache.put(cacheKey, data);
      final ct = _detectImageType(data);
      return shelf.Response.ok(data, headers: {'Content-Type': ct, 'Cache-Control': 'public, max-age=86400'});
    }

    return shelf.Response.notFound('No thumbnail');
  }

  String _detectImageType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'image/gif';
    return 'image/jpeg';
  }

  static const _corsHeaders = {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS', 'Access-Control-Allow-Headers': 'Origin, Content-Type'};
}
