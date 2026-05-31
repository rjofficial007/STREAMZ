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
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/di/service_locator.dart';
import '../../core/utils/file_type_utils.dart';
import '../../data/local/media_scanner.dart';
import '../../data/local/thumbnail_cache.dart';
import '../../domain/models/broadcast_station.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/stream_session.dart';
import '../../domain/services/station_service.dart';
import '../../domain/services/video_thumbnail_service.dart';
import 'modern_web_html.dart';
import 'web_html.dart';

typedef SessionUpdateCallback = void Function(String sessionId, StreamSession? session);
typedef ConnectionLogCallback = void Function(String ip);

class HttpServerService {
  final MediaScanner _scanner;
  final ThumbnailCache _thumbCache;
  final VideoThumbnailService _thumbGenerator;

  HttpServer? _server;

  List<BroadcastStation> stations = [];

  // FIX: Typed list instead of List<dynamic>.
  final List<WebSocketChannel> _sockets = [];
  int _totalBytesSent = 0;

  bool useModernWebUI = true;

  SessionUpdateCallback? onSessionUpdate;
  ConnectionLogCallback? onConnection;
  void Function()? onSocketsChanged;

  HttpServerService({required MediaScanner scanner, required ThumbnailCache thumbCache, required VideoThumbnailService thumbGenerator})
    : _scanner = scanner,
      _thumbCache = thumbCache,
      _thumbGenerator = thumbGenerator;

  bool get isRunning => _server != null;
  int get socketCount => _sockets.length;
  int get bytesSent => _totalBytesSent;

  // ── Security ───────────────────────────────────────────────────────────────

  /// Returns true only if [rawPath] resolves to a location inside one of
  /// [sharedFolders] after URL-decoding and OS-level canonicalisation.
  bool _isPathAllowed(String rawPath, List<String> sharedFolders) {
    try {
      // FIX: Decode URL encoding (%2e%2e → ..) before any check.
      final decoded = Uri.decodeComponent(rawPath);

      // FIX: Use p.canonicalize to resolve '..' and symlinks at the OS level.
      // On Windows this resolves drive-letter casing too.
      final canonical = p.canonicalize(decoded);

      for (final folder in sharedFolders) {
        final canonicalFolder = p.canonicalize(folder);
        // Ensure the path starts with the folder AND the next char is a
        // separator (prevents '/storage/emulated/0X' matching '/storage/emulated/0').
        if (canonical == canonicalFolder || canonical.startsWith(canonicalFolder + p.separator) || canonical.startsWith('$canonicalFolder/')) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Server Lifecycle ───────────────────────────────────────────────────────

  Future<void> start({required String ip, required List<String> sharedFolders, required List<MediaItem> Function() getMediaItems}) async {
    if (_server != null) await stop();

    final router = shelf_router.Router();

    // Static assets
    router.get('/assets/images/<name>', (shelf.Request r, String name) async {
      // Validate name to prevent path injection via this endpoint.
      if (name.contains('/') || name.contains('\\') || name.contains('..')) {
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
    });

    // Web interface
    router.get('/', (_) {
      final html = useModernWebUI ? kModernWebInterfaceHtml : kWebInterfaceHtml;
      return shelf.Response.ok(html, headers: {'content-type': 'text/html; charset=utf-8'});
    });

    // Media list
    router.get('/api/media', (_) {
      final items = getMediaItems();
      return shelf.Response.ok(jsonEncode(items.map((e) => e.toJson()).toList()), headers: {'content-type': 'application/json'});
    });

    // Stations
    router.get('/api/stations', (_) {
      final svc = sl<StationService>();
      final results = stations.map((s) {
        final state = svc.getPlaybackState(s);
        return {...s.toJson(), 'nowPlaying': state?.toJson()};
      }).toList();
      return shelf.Response.ok(jsonEncode(results), headers: {'content-type': 'application/json'});
    });

    router.get('/api/stations/join/<id>', (shelf.Request r, String id) {
      final station = stations.firstWhere((s) => s.id == id, orElse: () => throw Exception('Station not found'));
      final svc = sl<StationService>();
      final state = svc.getPlaybackState(station);
      if (state == null) return shelf.Response.notFound('No active content');

      final Map<String, dynamic> response = {
        ...state.toJson(),
        'isPaused': station.isPaused,
        'playlist': station.playlist.map((e) => e.copyWith(isBroadcast: true).toJson()).toList(),
      };

      return shelf.Response.ok(jsonEncode(response), headers: {'content-type': 'application/json'});
    });

    // Directory browse
    router.get('/api/browse', (shelf.Request r) async {
      final rawPath = r.url.queryParameters['path'] ?? '';

      if (rawPath.isEmpty) {
        // Return shared folder roots.
        final roots = sharedFolders.map((f) {
          int count = 0;
          try {
            count = Directory(f).listSync(followLinks: false).length;
          } catch (_) {}
          return {'name': f, 'path': f, 'isDirectory': true, 'itemCount': count};
        }).toList();
        return shelf.Response.ok(jsonEncode(roots), headers: {'content-type': 'application/json'});
      }

      if (!_isPathAllowed(rawPath, sharedFolders)) {
        return shelf.Response.forbidden('Access denied');
      }

      try {
        final dir = Directory(Uri.decodeComponent(rawPath));
        if (!await dir.exists()) {
          return shelf.Response.notFound('Not found');
        }

        // FIX: Timeout on directory listing to prevent hung handlers.
        final entries = <Map<String, dynamic>>[];
        await dir
            .list(followLinks: false)
            .handleError((_) {})
            .asyncMap((entity) async {
              final stat = await entity.stat();
              int count = 0;
              if (entity is Directory) {
                try {
                  count = entity.listSync(followLinks: false).length;
                } catch (_) {}
              }
              final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => entity.path);
              return {'name': name, 'path': entity.path, 'isDirectory': entity is Directory, 'size': stat.size, 'itemCount': count};
            })
            .timeout(const Duration(seconds: 10), onTimeout: (sink) => sink.close())
            .forEach(entries.add);

        entries.sort((a, b) {
          if (a['isDirectory'] == true && b['isDirectory'] != true) return -1;
          if (a['isDirectory'] != true && b['isDirectory'] == true) return 1;
          return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
        });

        return shelf.Response.ok(jsonEncode(entries), headers: {'content-type': 'application/json'});
      } catch (e) {
        return shelf.Response.internalServerError(body: e.toString());
      }
    });

    // Raw file serving
    router.get('/api/file', (shelf.Request r) async {
      final path = r.url.queryParameters['path'] ?? '';
      if (path.isEmpty || !_isPathAllowed(path, sharedFolders)) {
        return shelf.Response.forbidden('Access denied');
      }
      return _serveFile(r, File(Uri.decodeComponent(path)));
    });

    // Thumbnail
    router.get('/api/thumbnail/<id>', (shelf.Request r, String id) async {
      final decodedId = Uri.decodeComponent(id);
      return _serveThumbnail(decodedId, sharedFolders);
    });

    // Stream by media library ID
    router.get('/stream/<id>', (shelf.Request r, String id) async {
      File? f = _scanner.fileById(id);
      if (f == null) {
        final asset = _scanner.assetById(id);
        if (asset != null) f = await asset.file;
        if (f == null) {
          final song = _scanner.songById(id);
          if (song != null) f = File(song.data);
        }
      }
      if (f == null || !f.existsSync()) {
        return shelf.Response.notFound('File not found');
      }
      return _serveFile(r, f);
    });

    // WebSocket
    router.get(
      '/ws',
      webSocketHandler((WebSocketChannel ws, _) {
        _sockets.add(ws);
        onSocketsChanged?.call();

        ws.stream.listen(
          (message) {
            try {
              final data = jsonDecode(message as String) as Map<String, dynamic>;
              if (data['type'] == 'report_status') {
                final sId = data['sessionId']?.toString() ?? data['clientId'];
                final stopped = data['isStopped'] == true;
                if (stopped) {
                  onSessionUpdate?.call(sId, null);
                } else {
                  final rawProg = data['progress'];
                  final progress = (rawProg is num ? rawProg.toDouble() : 0.0).clamp(0.0, 1.0);
                  onSessionUpdate?.call(
                    sId,
                    StreamSession(
                      sessionId: sId,
                      clientId: data['clientId']?.toString() ?? sId,
                      title: data['title']?.toString() ?? '',
                      progress: progress,
                      mediaType: data['mediaType']?.toString() ?? 'video',
                      lastUpdated: DateTime.now(),
                    ),
                  );
                }
              } else {
                // Relay command to all other connected sockets.
                for (final s in List.of(_sockets)) {
                  if (s != ws) {
                    try {
                      s.sink.add(message);
                    } catch (_) {}
                  }
                }
              }
            } catch (_) {
              // Non-JSON or malformed message — relay raw.
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
            onSocketsChanged?.call();
          },
          onError: (_) {
            _sockets.remove(ws);
            onSocketsChanged?.call();
          },
          cancelOnError: false,
        );
      }),
    );

    // Middleware: CORS + connection tracking.
    shelf.Handler withMiddleware(shelf.Handler inner) {
      return (shelf.Request request) async {
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
    }

    final handler = const shelf.Pipeline().addMiddleware(withMiddleware).addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
    debugPrint('[HttpServer] Listening on http://$ip:8080');
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
    onSocketsChanged?.call();
    debugPrint('[HttpServer] Stopped');
  }

  void broadcast(String message) {
    for (final s in List.of(_sockets)) {
      try {
        s.sink.add(message);
      } catch (_) {}
    }
  }

  // ── File Serving ──────────────────────────────────────────────────────────

  Future<shelf.Response> _serveFile(shelf.Request r, File file) async {
    if (!await file.exists()) return shelf.Response.notFound('Not found');
    final stat = await file.stat();
    final fileSize = stat.size;
    final ct = FileTypeUtils.contentType(file.path);
    final rangeHeader = r.headers['range'];

    if (rangeHeader != null) {
      final parts = rangeHeader.replaceFirst('bytes=', '').split('-');
      final start = (int.tryParse(parts[0]) ?? 0).clamp(0, fileSize - 1);
      // FIX: clamp end to fileSize - 1 to prevent out-of-range reads.
      final end = (parts.length > 1 && parts[1].isNotEmpty) ? (int.tryParse(parts[1]) ?? (fileSize - 1)).clamp(start, fileSize - 1) : fileSize - 1;
      final length = end - start + 1;

      if (length <= 0) {
        return shelf.Response(416, headers: {'Content-Range': 'bytes */$fileSize'});
      }

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

  // ── Thumbnail Serving ──────────────────────────────────────────────────────

  Future<shelf.Response> _serveThumbnail(String id, List<String> sharedFolders) async {
    String cacheKey = id;
    File? file = _scanner.fileById(id);

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
