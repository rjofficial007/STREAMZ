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
