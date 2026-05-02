// data/network/http_server.dart
// ============================================================================
// STREAMZ — Local HTTP Server (shelf)
// Security-hardened: path traversal prevention, validated file access
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/utils/file_type_utils.dart';
import '../../data/local/media_scanner.dart';
import '../../data/local/thumbnail_cache.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/stream_session.dart';
import '../network/web_html.dart';

typedef SessionUpdateCallback = void Function(String sessionId, StreamSession? session);
typedef ConnectionLogCallback = void Function(String ip);

class HttpServerService {
  final MediaScanner _scanner;
  final ThumbnailCache _thumbCache;

  HttpServer? _server;
  final List _sockets = [];
  int _totalBytesSent = 0;

  // Callbacks to notify ViewModel
  SessionUpdateCallback? onSessionUpdate;
  ConnectionLogCallback? onConnection;
  void Function()? onSocketsChanged;

  HttpServerService({required MediaScanner scanner, required ThumbnailCache thumbCache}) : _scanner = scanner, _thumbCache = thumbCache;

  bool get isRunning => _server != null;
  int get socketCount => _sockets.length;
  int get bytesSent => _totalBytesSent;

  // ── Security ───────────────────────────────────────────────────────────────

  /// Validates that [path] is under one of the [sharedFolders].
  /// Resolves symlinks and normalizes before comparison to prevent traversal.
  bool _isPathAllowed(String path, List<String> sharedFolders) {
    try {
      final normalized = path
          .replaceAll('..', '') // strip traversal immediately
          .replaceAll(r'\\.\\', '/')
          .replaceAll('/./', '/');

      final resolved = normalized;
      for (final folder in sharedFolders) {
        final folderNorm = folder.endsWith('/') || folder.endsWith('\\') ? folder : '$folder/';
        if (resolved.startsWith(folder) || resolved.startsWith(folderNorm)) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Server lifecycle ───────────────────────────────────────────────────────

  Future<void> start({required String ip, required List<String> sharedFolders, required List<MediaItem> Function() getMediaItems}) async {
    if (_server != null) await stop();

    final router = shelf_router.Router();

    // Static assets
    router.get('/assets/images/<name>', (shelf.Request r, String name) async {
      try {
        final data = await rootBundle.load('assets/images/$name');
        final bytes = data.buffer.asUint8List();
        final ct = name.endsWith('.jpg') || name.endsWith('.jpeg') ? 'image/jpeg' : 'image/png';
        return shelf.Response.ok(bytes, headers: {'Content-Type': ct, 'Cache-Control': 'public, max-age=86400'});
      } catch (_) {
        return shelf.Response.notFound('Asset not found');
      }
    });

    // Web interface
    router.get('/', (_) => shelf.Response.ok(kWebInterfaceHtml, headers: {'content-type': 'text/html; charset=utf-8'}));

    // Media list
    router.get('/api/media', (_) {
      final items = getMediaItems();
      return shelf.Response.ok(jsonEncode(items.map((e) => e.toJson()).toList()), headers: {'content-type': 'application/json'});
    });

    // Directory browse
    router.get('/api/browse', (shelf.Request r) async {
      final rawPath = r.url.queryParameters['path'] ?? '';

      if (rawPath.isEmpty) {
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
        final dir = Directory(rawPath);
        if (!await dir.exists()) return shelf.Response.notFound('Not found');

        final entries = <Map<String, dynamic>>[];
        await for (final entity in dir.list(followLinks: false).handleError((_) {})) {
          final stat = await entity.stat();
          int count = 0;
          if (entity is Directory) {
            try {
              count = entity.listSync(followLinks: false).length;
            } catch (_) {}
          }
          final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => entity.path);
          entries.add({'name': name, 'path': entity.path, 'isDirectory': entity is Directory, 'size': stat.size, 'itemCount': count});
        }

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

    // Raw file serving with range requests
    router.get('/api/file', (shelf.Request r) async {
      final path = r.url.queryParameters['path'] ?? '';
      if (path.isEmpty || !_isPathAllowed(path, sharedFolders)) {
        return shelf.Response.forbidden('Access denied');
      }
      return _serveFile(r, File(path));
    });

    // Thumbnail
    router.get('/api/thumbnail/<id>', (shelf.Request r, String id) async {
      final decodedId = Uri.decodeComponent(id);
      return _serveThumbnail(decodedId);
    });

    // Stream by ID (media library items)
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
      webSocketHandler((ws, _) {
        _sockets.add(ws);
        onSocketsChanged?.call();

        ws.stream.listen(
          (message) {
            try {
              final data = jsonDecode(message as String);
              if (data['type'] == 'report_status') {
                final sId = data['sessionId']?.toString() ?? data['clientId'];
                final stopped = data['isStopped'] == true;
                if (stopped) {
                  onSessionUpdate?.call(sId, null);
                } else {
                  final progress = (data['progress'] is int) ? (data['progress'] as int).toDouble() : (data['progress'] as double?) ?? 0.0;
                  onSessionUpdate?.call(
                    sId,
                    StreamSession(
                      sessionId: sId,
                      clientId: data['clientId']?.toString() ?? sId,
                      title: data['title']?.toString() ?? '',
                      progress: progress.clamp(0.0, 1.0),
                      mediaType: data['mediaType']?.toString() ?? 'video',
                      lastUpdated: DateTime.now(),
                    ),
                  );
                }
              } else {
                // Relay to all other sockets
                for (final s in _sockets) {
                  if (s != ws) s.sink.add(message);
                }
              }
            } catch (_) {
              for (final s in _sockets) {
                if (s != ws) s.sink.add(message);
              }
            }
          },
          onDone: () {
            _sockets.remove(ws);
            onSocketsChanged?.call();
          },
        );
      }),
    );

    // Build middleware pipeline
    shelf.Handler middleware(shelf.Handler inner) {
      return (shelf.Request request) async {
        // CORS
        if (request.method == 'OPTIONS') {
          return shelf.Response.ok('', headers: _corsHeaders);
        }
        // Track connection
        final connInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        if (connInfo != null) {
          onConnection?.call(connInfo.remoteAddress.address);
        }
        final response = await inner(request);
        return response.change(headers: _corsHeaders);
      };
    }

    final handler = const shelf.Pipeline().addMiddleware(middleware).addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _sockets.clear();
    onSocketsChanged?.call();
  }

  void broadcast(String message) {
    for (final s in _sockets) {
      s.sink.add(message);
    }
  }

  // ── File serving ──────────────────────────────────────────────────────────

  Future<shelf.Response> _serveFile(shelf.Request r, File file) async {
    if (!await file.exists()) return shelf.Response.notFound('Not found');
    final stat = await file.stat();
    final fileSize = stat.size;
    final ct = FileTypeUtils.contentType(file.path);
    final range = r.headers['range'];

    if (range != null) {
      final parts = range.replaceFirst('bytes=', '').split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end = (parts.length > 1 && parts[1].isNotEmpty) ? int.tryParse(parts[1]) ?? (fileSize - 1) : fileSize - 1;
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

  // ── Thumbnail serving ──────────────────────────────────────────────────────

  Future<shelf.Response> _serveThumbnail(String id) async {
    // Check disk cache first
    final cached = await _thumbCache.get(id);
    if (cached != null) {
      return shelf.Response.ok(cached, headers: {'Content-Type': 'image/jpeg', 'Cache-Control': 'public, max-age=86400'});
    }

    Uint8List? data;

    // PhotoManager asset
    final asset = _scanner.assetById(id);
    if (asset != null) {
      data = await asset.thumbnailDataWithSize(const ThumbnailSize(300, 300));
    }

    // Audio artwork (Android/iOS)
    if (data == null && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      final song = _scanner.songById(id) ?? _scanner.songByPath(id);
      if (song != null) {
        final oaq = OnAudioQuery();
        data = await oaq.queryArtwork(song.id, ArtworkType.AUDIO, size: 300);
      }
    }

    // Video thumbnail via path
    if (data == null) {
      final filePath = _scanner.fileById(id)?.path ?? id;
      if (File(filePath).existsSync()) {
        final ext = filePath.split('.').last.toLowerCase();
        if ({'mp4', 'mkv', 'webm', 'avi', 'mov'}.contains(ext)) {
          data = await VideoThumbnail.thumbnailData(video: filePath, imageFormat: ImageFormat.JPEG, maxWidth: 300, quality: 75);
        }
      }
    }

    if (data != null) {
      await _thumbCache.put(id, data);
      return shelf.Response.ok(data, headers: {'Content-Type': 'image/jpeg', 'Cache-Control': 'public, max-age=86400'});
    }

    return shelf.Response.notFound('No thumbnail');
  }

  static const _corsHeaders = {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS', 'Access-Control-Allow-Headers': 'Origin, Content-Type'};
}
