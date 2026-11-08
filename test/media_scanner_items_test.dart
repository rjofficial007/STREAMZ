// test/media_scanner_items_test.dart
// ============================================================================
// Runnable check for A2:
// MediaScanner.buildMediaItems must surface directory-scanned (mounted
// folder) files on non-Windows platforms, not just Windows.
//
// Pure-Dart: no platform channels, runnable under `flutter test`.
// (defaultTargetPlatform in flutter_test is android — i.e. the
// non-Windows path that A2 fixed.)
// ============================================================================

import 'dart:io';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:streamz/data/local/media_scanner.dart';
import 'package:streamz/domain/models/media_item.dart';

List<MediaItem> _build(
  MediaScanner s, {
  bool videos = true,
  bool music = true,
  bool images = true,
}) => s.buildMediaItems(
  shareVideos: videos,
  shareMusic: music,
  shareImages: images,
  getProgress: (_) => 0,
  getTimestamp: (_) => 0,
);

void main() {
  group('A2: mounted-folder media surfaces on non-Windows platforms', () {
    test(
      'photo-library scan pages large albums without dropping assets',
      () async {
        final previousPlugin = PhotoManager.plugin;
        final plugin = _PagedPhotoManagerPlugin(assetCount: 513);
        try {
          PhotoManager.withPlugin(plugin);
          final scanner = MediaScanner();
          await scanner.scanPhotoManager(
            includeVideos: true,
            includeImages: false,
          );

          expect(plugin.requestedPages, [0, 1, 2]);
          expect(plugin.largestRequestedPage, 256);
          expect(scanner.localAssets, hasLength(513));
          expect(scanner.assetFolders.values.toSet(), {'Camera'});
          expect(
            scanner.assetById('asset-512'),
            same(scanner.localAssets.last),
          );
        } finally {
          PhotoManager.withPlugin(previousPlugin);
        }
      },
    );

    test('photo and audio lookups use their scan-built ID indexes', () {
      final scanner = MediaScanner();
      final song = SongModel({'_id': 42, '_data': '/music/track.mp3'});
      scanner.localSongs = [song];

      expect(scanner.songById('42'), same(song));
      expect(scanner.songByPath('/music/track.mp3'), same(song));
      expect(scanner.songById('missing'), isNull);
    });

    test('large directory scans deliver bounded incremental batches', () async {
      final root = await Directory.systemTemp.createTemp(
        'streamz_media_scan_large_',
      );
      try {
        for (var index = 0; index < 520; index++) {
          await File('${root.path}/$index.mp4').create();
        }

        final scanner = MediaScanner();
        final batchSizes = <int>[];
        await scanner.scanDirectory(
          root.path,
          includeVideos: true,
          includeAudio: false,
          includeImages: false,
          onBatch: (batch) => batchSizes.add(batch.length),
        );

        expect(scanner.scannedFiles, hasLength(520));
        expect(batchSizes.length, greaterThan(1));
        expect(batchSizes.every((size) => size <= 256), isTrue);
      } finally {
        await root.delete(recursive: true);
      }
    });

    test(
      'directory scan keeps distinct files with long common path prefixes',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'streamz_media_scan_',
        );
        try {
          for (final name in ['first.mp4', 'second.mp4']) {
            await File('${root.path}/$name').create();
          }

          final scanner = MediaScanner();
          await scanner.scanDirectory(
            root.path,
            includeVideos: true,
            includeAudio: true,
            includeImages: true,
            onBatch: (_) {},
          );

          final items = _build(scanner);
          expect(items, hasLength(2));
          expect(items.map((item) => item.id).toSet(), hasLength(2));
          expect(items.map((item) => item.title).toSet(), {
            'first.mp4',
            'second.mp4',
          });
          final legacyId = hex
              .encode('${root.path}/second.mp4'.codeUnits)
              .substring(0, 32);
          expect(items.map((item) => item.id), contains(legacyId));
        } finally {
          await root.delete(recursive: true);
        }
      },
    );

    test('directory-scanned video appears in the library', () {
      final s = MediaScanner();
      s.scannedFiles['id1'] = File('/mnt/shared/movies/sample.mp4');

      final items = _build(s);

      final match = items.where((m) => m.id == 'id1').toList();
      expect(
        match,
        hasLength(1),
        reason:
            'scanned folder files must appear in buildMediaItems on '
            'every non-web platform (flutter_test default target: android)',
      );
      expect(match.first.isVideo, isTrue);
      expect(match.first.title, 'sample.mp4');
      expect(match.first.folder, 'movies');
    });

    test('shareVideos=false filters the scanned video out', () {
      final s = MediaScanner();
      s.scannedFiles['id1'] = File('/mnt/shared/movies/sample.mp4');
      expect(_build(s, videos: false).where((m) => m.id == 'id1'), isEmpty);
    });

    test('scanned audio respects the shareMusic filter', () {
      final s = MediaScanner();
      s.scannedFiles['a1'] = File('/mnt/shared/music/track.flac');
      s.scannedFiles['v1'] = File('/mnt/shared/movies/clip.mp4');

      final off = _build(s, music: false);
      expect(off.where((m) => m.id == 'a1'), isEmpty);
      expect(off.where((m) => m.id == 'v1'), hasLength(1));
    });
  });
}

class _PagedPhotoManagerPlugin extends PhotoManagerPlugin {
  _PagedPhotoManagerPlugin({required this.assetCount});

  final int assetCount;
  final List<int> requestedPages = [];
  int largestRequestedPage = 0;

  @override
  Future<PermissionState> requestPermissionExtend(
    PermissionRequestOption requestOption,
  ) async => PermissionState.authorized;

  @override
  Future<List<AssetPathEntity>> getAssetPathList({
    bool hasAll = true,
    bool onlyAll = false,
    RequestType type = RequestType.common,
    PMFilter? filterOption,
    required PMPathFilter pathFilterOption,
  }) async => [
    AssetPathEntity(id: 'all', name: 'All', type: type, isAll: true),
    AssetPathEntity(id: 'camera', name: 'Camera', type: type),
  ];

  @override
  Future<int> getAssetCountFromPath(AssetPathEntity path) async => assetCount;

  @override
  Future<List<AssetEntity>> getAssetListPaged(
    String id, {
    required PMFilter? optionGroup,
    int page = 0,
    int size = 15,
    RequestType type = RequestType.common,
  }) async {
    requestedPages.add(page);
    largestRequestedPage = size > largestRequestedPage
        ? size
        : largestRequestedPage;
    final start = page * size;
    final end = (start + size).clamp(start, assetCount).toInt();
    return List.generate(
      end - start,
      (index) => AssetEntity(
        id: 'asset-${start + index}',
        typeInt: AssetType.video.index,
        width: 1,
        height: 1,
        title: 'Video ${start + index}',
      ),
      growable: false,
    );
  }
}
