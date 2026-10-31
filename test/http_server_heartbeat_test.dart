import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamz/data/local/media_scanner.dart';
import 'package:streamz/data/local/thumbnail_cache.dart';
import 'package:streamz/data/network/http_server.dart';
import 'package:streamz/data/repositories/server_repository.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/services/queue_service.dart';
import 'package:streamz/domain/services/remote_command_service.dart';
import 'package:streamz/domain/services/station_service.dart';
import 'package:streamz/domain/services/video_thumbnail_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'station sync is scoped to members and heartbeat frees a silent master',
    () async {
      final testOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      try {
        await _verifyHeartbeatLease();
      } finally {
        HttpOverrides.global = testOverrides;
      }
    },
  );

  test('folder browse pages keep their sorted results', () async {
    final testOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await _verifyBrowsePages();
    } finally {
      HttpOverrides.global = testOverrides;
    }
  });

  test('reconnect snapshot and catalog revisions stay in sync', () async {
    final testOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await _verifyRecoverySnapshot();
    } finally {
      HttpOverrides.global = testOverrides;
    }
  });

  test('WebSocket client admission stays within the configured cap', () async {
    final testOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await _verifyWebSocketCapacity();
    } finally {
      HttpOverrides.global = testOverrides;
    }
  });

  test('file stream admission stays within the configured cap', () async {
    final testOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await _verifyFileStreamCapacity();
    } finally {
      HttpOverrides.global = testOverrides;
    }
  });

  test('remote socket reconnects after the host returns', () async {
    final testOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await _verifyRemoteSocketReconnect();
    } finally {
      HttpOverrides.global = testOverrides;
    }
  });
}

Future<void> _verifyWebSocketCapacity() async {
  SharedPreferences.setMockInitialValues({});
  final server = HttpServerService(
    scanner: MediaScanner(),
    thumbCache: ThumbnailCache(),
    thumbGenerator: VideoThumbnailService(),
    stationService: StationService(),
    queueService: QueueService(),
    serverRepository: ServerRepository(await SharedPreferences.getInstance()),
  )..pairingToken = 'capacity-test-token';
  await server.start(
    ip: '127.0.0.1',
    sharedFolders: const [],
    getMediaItems: () => const [],
    getMediaRevision: () => 'capacity-test',
  );

  final peers = <_HeartbeatPeer>[];
  try {
    for (var index = 0; index < 32; index++) {
      peers.add(await _connectCapacityPeer(index));
    }
    expect(server.socketCount, 32);

    final cappedChannel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8080/ws'),
      protocols: const ['capacity-test-token'],
    );
    await cappedChannel.ready.timeout(const Duration(seconds: 5));
    await cappedChannel.stream.drain<void>().timeout(
      const Duration(seconds: 5),
    );
    expect(cappedChannel.closeCode, 4002);
    expect(server.socketCount, 32);
  } finally {
    for (final peer in peers) {
      await peer.close();
    }
    await server.stop();
  }
}

Future<_HeartbeatPeer> _connectCapacityPeer(int index) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:8080/ws'),
    protocols: const ['capacity-test-token'],
  );
  final peer = _HeartbeatPeer(channel);
  await peer.waitFor('ready').timeout(const Duration(seconds: 5));
  channel.sink.add(
    jsonEncode({
      'type': 'system',
      'action': 'heartbeat',
      'value': {'clientId': 'capacity-client-$index', 'sequence': 1},
    }),
  );
  await peer.waitFor('heartbeat_ack').timeout(const Duration(seconds: 5));
  return peer;
}

Future<void> _verifyFileStreamCapacity() async {
  SharedPreferences.setMockInitialValues({});
  final directory = await Directory.systemTemp.createTemp('streamz_stream_');
  final mediaFile = File('${directory.path}/large.mp4');
  final file = await mediaFile.open(mode: FileMode.write);
  await file.truncate(64 * 1024 * 1024);
  await file.close();

  final server = HttpServerService(
    scanner: MediaScanner(),
    thumbCache: ThumbnailCache(),
    thumbGenerator: VideoThumbnailService(),
    stationService: StationService(),
    queueService: QueueService(),
    serverRepository: ServerRepository(await SharedPreferences.getInstance()),
  );
  await server.start(
    ip: '127.0.0.1',
    sharedFolders: [directory.path],
    getMediaItems: () => const [],
    getMediaRevision: () => 'stream-capacity-test',
  );

  final clients = List.generate(9, (_) => http.Client());
  final responses = <http.StreamedResponse>[];
  try {
    for (var index = 0; index < 8; index++) {
      final response = await clients[index]
          .send(_fileRequest(mediaFile.path))
          .timeout(const Duration(seconds: 5));
      expect(response.statusCode, 200);
      responses.add(response);
    }

    final overflow = await clients.last
        .send(_fileRequest(mediaFile.path))
        .timeout(const Duration(seconds: 5));
    expect(overflow.statusCode, 503);
    expect(overflow.headers['retry-after'], '2');
    await overflow.stream.drain<void>();
  } finally {
    for (final response in responses) {
      final subscription = response.stream.listen((_) {}, onError: (_) {});
      await subscription.cancel();
    }
    for (final client in clients) {
      client.close();
    }
    await server.stop();
    await directory.delete(recursive: true);
  }
}

http.Request _fileRequest(String path) => http.Request(
  'GET',
  Uri.http('127.0.0.1:8080', '/api/file', {'path': path}),
);

Future<void> _verifyRemoteSocketReconnect() async {
  SharedPreferences.setMockInitialValues({});
  final server = HttpServerService(
    scanner: MediaScanner(),
    thumbCache: ThumbnailCache(),
    thumbGenerator: VideoThumbnailService(),
    stationService: StationService(),
    queueService: QueueService(),
    serverRepository: ServerRepository(await SharedPreferences.getInstance()),
  )..pairingToken = 'reconnect-test-token';

  Future<void> startServer() => server.start(
    ip: '127.0.0.1',
    sharedFolders: const [],
    getMediaItems: () => const [],
    getMediaRevision: () => 'reconnect-test',
  );

  final remote = RemoteCommandService(clientId: 'reconnect-test-client');
  final initiallyConnected = Completer<void>();
  final disconnected = Completer<void>();
  final reconnected = Completer<void>();
  remote.addListener(() {
    if (remote.isConnected) {
      if (!initiallyConnected.isCompleted) {
        initiallyConnected.complete();
      } else if (disconnected.isCompleted && !reconnected.isCompleted) {
        reconnected.complete();
      }
    } else if (initiallyConnected.isCompleted && !disconnected.isCompleted) {
      disconnected.complete();
    }
  });

  try {
    await startServer();
    remote.connect('127.0.0.1', token: 'reconnect-test-token');
    await initiallyConnected.future.timeout(const Duration(seconds: 5));

    await server.stop();
    await disconnected.future.timeout(const Duration(seconds: 5));

    await startServer();
    await reconnected.future.timeout(const Duration(seconds: 8));
    expect(remote.isConnected, isTrue);
  } finally {
    remote.dispose();
    await server.stop();
  }
}

Future<void> _verifyRecoverySnapshot() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final queue = QueueService()
    ..addItem(
      const MediaItem(
        id: 'queued-media',
        title: 'Queued media',
        duration: 60,
        type: 'video',
        folder: 'test',
      ),
      'SERVER',
    );
  var catalogRevision = 'catalog-v1';
  var catalog = const [
    MediaItem(
      id: 'media-v1',
      title: 'First media',
      duration: 120,
      type: 'video',
      folder: 'test',
    ),
  ];
  final server =
      HttpServerService(
          scanner: MediaScanner(),
          thumbCache: ThumbnailCache(),
          thumbGenerator: VideoThumbnailService(),
          stationService: StationService(),
          queueService: queue,
          serverRepository: ServerRepository(preferences),
        )
        ..pairingToken = 'snapshot-test-token'
        ..stations = [
          BroadcastStation(
            id: 'snapshot-station',
            name: 'Snapshot station',
            playlist: catalog,
            startTime: DateTime.now(),
          ),
        ];
  await server.start(
    ip: '127.0.0.1',
    sharedFolders: const [],
    getMediaItems: () => catalog,
    getMediaRevision: () => catalogRevision,
  );

  _HeartbeatPeer? peer;
  try {
    final localFontResponse = await http.get(
      Uri.http('127.0.0.1:8080', '/assets/fonts/Manrope-Variable.ttf'),
    );
    expect(localFontResponse.statusCode, 200);
    expect(localFontResponse.headers['content-type'], 'font/ttf');
    expect(localFontResponse.bodyBytes.length, greaterThan(100000));

    final healthResponse = await http.get(
      Uri.http('127.0.0.1:8080', '/api/health'),
    );
    expect(healthResponse.statusCode, 200);
    final health = jsonDecode(healthResponse.body) as Map<String, dynamic>;
    expect(health['ready'], isTrue);
    expect(health['protocolVersion'], 1);

    final firstCatalog = await http.get(
      Uri.http('127.0.0.1:8080', '/api/media'),
    );
    expect(firstCatalog.statusCode, 200);
    expect(firstCatalog.headers['etag'], '"${health['catalogRevision']}"');
    expect(jsonDecode(firstCatalog.body), hasLength(1));
    final cachedCatalog = await http.get(
      Uri.http('127.0.0.1:8080', '/api/media'),
      headers: {'If-None-Match': firstCatalog.headers['etag']!},
    );
    expect(cachedCatalog.statusCode, 304);

    peer = await _connectSnapshotPeer();
    final firstReady = await peer.waitFor('ready');
    expect(firstReady['value'], {
      'protocolVersion': 1,
      'catalogRevision': health['catalogRevision'],
      'stationRevision': health['stationRevision'],
      'queueRevision': health['queueRevision'],
    });
    final firstQueue = await peer.waitFor('update');
    expect((firstQueue['value'] as Map)['revision'], health['queueRevision']);
    expect((firstQueue['value'] as Map)['items'], hasLength(1));
    await peer.close();
    peer = null;

    catalogRevision = 'catalog-v2';
    catalog = [
      ...catalog,
      const MediaItem(
        id: 'media-v2',
        title: 'Second media',
        duration: 90,
        type: 'video',
        folder: 'test',
      ),
    ];
    final changedCatalog = await http.get(
      Uri.http('127.0.0.1:8080', '/api/media'),
    );
    final changedHealthResponse = await http.get(
      Uri.http('127.0.0.1:8080', '/api/health'),
    );
    final changedHealth =
        jsonDecode(changedHealthResponse.body) as Map<String, dynamic>;
    expect(changedCatalog.statusCode, 200);
    expect(
      changedCatalog.headers['etag'],
      '"${changedHealth['catalogRevision']}"',
    );
    expect(jsonDecode(changedCatalog.body), hasLength(2));

    peer = await _connectSnapshotPeer();
    final reconnectReady = await peer.waitFor('ready');
    expect(
      (reconnectReady['value'] as Map)['catalogRevision'],
      changedHealth['catalogRevision'],
    );
    final reconnectQueue = await peer.waitFor('update');
    expect(
      (reconnectQueue['value'] as Map)['revision'],
      health['queueRevision'],
    );
  } finally {
    await peer?.close();
    await server.stop();
  }
}

Future<_HeartbeatPeer> _connectSnapshotPeer() async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:8080/ws'),
    protocols: const ['snapshot-test-token'],
  );
  return _HeartbeatPeer(channel);
}

Future<void> _verifyBrowsePages() async {
  SharedPreferences.setMockInitialValues({});
  final directory = await Directory.systemTemp.createTemp('streamz_browse_');
  await File('${directory.path}/beta.mp4').writeAsBytes([1]);
  await File('${directory.path}/alpha.mkv').writeAsBytes([2]);
  await File('${directory.path}/gamma.mp3').writeAsBytes([3]);

  final preferences = await SharedPreferences.getInstance();
  final server = HttpServerService(
    scanner: MediaScanner(),
    thumbCache: ThumbnailCache(),
    thumbGenerator: VideoThumbnailService(),
    stationService: StationService(),
    queueService: QueueService(),
    serverRepository: ServerRepository(preferences),
  );
  await server.start(
    ip: '127.0.0.1',
    sharedFolders: [directory.path],
    getMediaItems: () => const [],
    getMediaRevision: () => 'browse-test',
  );

  try {
    final firstPage = await http.get(
      Uri.http('127.0.0.1:8080', '/api/browse', {
        'path': directory.path,
        'offset': '0',
        'limit': '2',
      }),
    );
    expect(firstPage.statusCode, 200);
    final firstResult = jsonDecode(firstPage.body) as Map<String, dynamic>;
    expect(
      (firstResult['items'] as List)
          .map((item) => (item as Map<String, dynamic>)['name'])
          .toList(),
      ['alpha.mkv', 'beta.mp4'],
    );
    expect(firstResult['hasMore'], isTrue);

    final secondPage = await http.get(
      Uri.http('127.0.0.1:8080', '/api/browse', {
        'path': directory.path,
        'offset': '2',
        'limit': '2',
      }),
    );
    expect(secondPage.statusCode, 200);
    final secondResult = jsonDecode(secondPage.body) as Map<String, dynamic>;
    expect(
      (secondResult['items'] as List)
          .map((item) => (item as Map<String, dynamic>)['name'])
          .toList(),
      ['gamma.mp3'],
    );
    expect(secondResult['hasMore'], isFalse);
  } finally {
    await server.stop();
    await directory.delete(recursive: true);
  }
}

Future<void> _verifyHeartbeatLease() async {
  SharedPreferences.setMockInitialValues({});
  final repository = ServerRepository(await SharedPreferences.getInstance());
  final server =
      HttpServerService(
          scanner: MediaScanner(),
          thumbCache: ThumbnailCache(),
          thumbGenerator: VideoThumbnailService(),
          stationService: StationService(),
          queueService: QueueService(),
          serverRepository: repository,
        )
        ..pairingToken = 'heartbeat-test-token'
        ..stations = [
          BroadcastStation(
            id: 'station-1',
            name: 'Test station',
            playlist: const [
              MediaItem(
                id: 'media-1',
                title: 'Test media',
                duration: 120,
                type: 'video',
                folder: 'test',
              ),
            ],
            startTime: DateTime.now(),
          ),
        ];
  final sessionUpdates = <String>[];
  server.onSessionUpdate = (sessionId, session) {
    sessionUpdates.add('$sessionId:${session == null ? 'stopped' : 'active'}');
  };
  _HeartbeatPeer? firstPeer;
  _HeartbeatPeer? statusPeer;
  _HeartbeatPeer? unrelatedPeer;
  _HeartbeatPeer? legacyPeer;
  _HeartbeatPeer? replacementPeer;

  await server.start(
    ip: '127.0.0.1',
    sharedFolders: const [],
    getMediaItems: () => const [],
    getMediaRevision: () => 'test',
  );
  addTearDown(() async {
    await firstPeer?.close();
    await statusPeer?.close();
    await unrelatedPeer?.close();
    await legacyPeer?.close();
    await replacementPeer?.close();
    await server.stop();
  });

  firstPeer = await _connectPeer('client-1');
  expect(await _joinRole('client-1'), 'master');

  statusPeer = await _connectPeer('client-2');
  expect(await _joinRole('client-2'), 'slave');
  unrelatedPeer = await _connectPeer('client-4');
  legacyPeer = await _connectPeer('client-5');
  firstPeer.channel.sink.add(
    jsonEncode({
      'type': 'media',
      'action': 'sync_state',
      'senderId': 'client-1',
      'value': {
        'stationId': 'station-1',
        'pos': 1000,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    }),
  );
  final unrelatedSync = expectLater(
    unrelatedPeer
        .waitFor('sync_state')
        .timeout(const Duration(milliseconds: 150)),
    throwsA(isA<TimeoutException>()),
  );
  expect(await statusPeer.waitFor('sync_state'), isNotNull);
  await unrelatedSync;

  firstPeer.channel.sink.add(
    jsonEncode({
      'type': 'media',
      'action': 'sync_state',
      'senderId': 'client-1',
      'value': {'pos': 1500, 'ts': DateTime.now().millisecondsSinceEpoch},
    }),
  );
  expect(await legacyPeer.waitFor('sync_state'), isNotNull);

  firstPeer.channel.sink.add(
    jsonEncode({
      'type': 'report_status',
      'clientId': 'client-1',
      'sessionId': 'session-1',
      'title': 'Test media',
      'mediaId': 'media-1',
      'progress': 0.25,
      'position': 30,
      'mediaType': 'video',
      'isStopped': false,
    }),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  expect(sessionUpdates, ['session-1:active']);
  await expectLater(
    statusPeer
        .waitFor('report_status')
        .timeout(const Duration(milliseconds: 150)),
    throwsA(isA<TimeoutException>()),
  );
  await statusPeer.close();
  statusPeer = null;
  await Future<void>.delayed(const Duration(milliseconds: 50));
  expect(server.socketCount, 3);

  server.expireUnresponsiveClientsAt(
    DateTime.now().add(const Duration(seconds: 46)),
  );

  expect(server.socketCount, 0);
  expect(await firstPeer.waitFor('sync_master_available'), isNotNull);

  replacementPeer = await _connectPeer('client-3');
  expect(await _joinRole('client-3'), 'master');
  statusPeer = await _connectPeer('client-2');
  expect(await _joinRole('client-2'), 'slave');
  replacementPeer.channel.sink.add(
    jsonEncode({
      'type': 'media',
      'action': 'sync_state',
      'senderId': 'client-3',
      'value': {
        'stationId': 'station-1',
        'pos': 2500,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    }),
  );
  expect(await statusPeer.waitFor('sync_state'), isNotNull);
}

Future<_HeartbeatPeer> _connectPeer(String clientId) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:8080/ws'),
    protocols: const ['heartbeat-test-token'],
  );
  final peer = _HeartbeatPeer(channel);
  await peer.waitFor('ready').timeout(const Duration(seconds: 5));
  channel.sink.add(
    jsonEncode({
      'type': 'system',
      'action': 'heartbeat',
      'value': {'clientId': clientId, 'sequence': 1},
    }),
  );
  await peer.waitFor('heartbeat_ack').timeout(const Duration(seconds: 5));
  return peer;
}

Future<String> _joinRole(String clientId) async {
  final response = await http
      .get(
        Uri.parse(
          'http://127.0.0.1:8080/api/stations/join/station-1'
          '?clientId=$clientId',
        ),
      )
      .timeout(const Duration(seconds: 5));
  expect(response.statusCode, 200);
  return (jsonDecode(response.body) as Map<String, dynamic>)['syncRole']
      as String;
}

class _HeartbeatPeer {
  _HeartbeatPeer(this.channel) : _messages = StreamIterator(channel.stream);

  final WebSocketChannel channel;
  final StreamIterator<dynamic> _messages;

  Future<Map<String, dynamic>> waitFor(String action) async {
    while (await _messages.moveNext()) {
      final message =
          jsonDecode(_messages.current as String) as Map<String, dynamic>;
      if (message['action'] == action) return message;
    }
    throw StateError('WebSocket closed before $action');
  }

  Future<void> close() async {
    await _messages.cancel();
    await channel.sink.close();
  }
}
