// test/server_settings_test.dart
// ============================================================================
// Runnable check for E1:
// Server settings (mounted folders, share filters, web-UI toggle, no-trace)
// must survive an app restart — a fresh ServerRepository instance (same
// prefs) must restore exactly what was saved.
//
// Pure-Dart with mocked SharedPreferences: runnable under `flutter test`.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streamz/data/repositories/server_repository.dart';

void main() {
  group('E1: server settings persistence', () {
    test('round-trips through a fresh repository (simulated restart)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final repo1 = ServerRepository(prefs);
      await repo1.saveSettings({
        'sharedFolders': ['/mnt/shared/movies', '/mnt/shared/music'],
        'useModernWebUI': false,
        'shareVideos': true,
        'shareImages': false,
        'shareMusic': true,
        'zeroTrace': true,
      });

      // App "restarts": a brand-new repository over the same prefs.
      final repo2 = ServerRepository(await SharedPreferences.getInstance());
      final loaded = repo2.loadSettings();

      expect(loaded['sharedFolders'], ['/mnt/shared/movies', '/mnt/shared/music']);
      expect(loaded['useModernWebUI'], false);
      expect(loaded['shareVideos'], true);
      expect(loaded['shareImages'], false);
      expect(loaded['shareMusic'], true);
      expect(loaded['zeroTrace'], true);
    });

    test('corrupt settings blob falls back to empty (defaults)', () async {
      SharedPreferences.setMockInitialValues({'server_settings': '{definitely not json'});
      final repo = ServerRepository(await SharedPreferences.getInstance());
      expect(repo.loadSettings(), isEmpty);
    });

    test('no settings yet returns empty (first launch keeps defaults)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ServerRepository(await SharedPreferences.getInstance());
      expect(repo.loadSettings(), isEmpty);
    });
  });
}
