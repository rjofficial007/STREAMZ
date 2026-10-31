// test/robustness_test.dart
// ============================================================================
// Runnable checks for the P2 hardening batch:
//
//  C1 — HttpServerService.parseRange: clamping behavior + the empty-file
//       case that used to throw RangeError (500) on any Range request.
//  C3 — ServerRepository.logAccess: connection history is capped at 200
//       entries (was unbounded in memory and in prefs).
//
// Pure-Dart: no platform channels, runnable under `flutter test`.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streamz/data/network/http_server.dart';
import 'package:streamz/data/repositories/server_repository.dart';

void main() {
  group('C1: Range header parsing', () {
    test('normal range passes through', () {
      expect(HttpServerService.parseRange('bytes=0-99', 1000), (0, 99));
    });

    test('open-ended range clamps to file end', () {
      expect(HttpServerService.parseRange('bytes=900-', 1000), (900, 999));
    });

    test('oversized end clamps to file end', () {
      expect(HttpServerService.parseRange('bytes=100-5000', 1000), (100, 999));
    });

    test('start past end clamps to the last byte', () {
      expect(HttpServerService.parseRange('bytes=9999-', 1000), (999, 999));
    });

    test('empty file is unsatisfiable (was a RangeError 500)', () {
      expect(HttpServerService.parseRange('bytes=0-99', 0), isNull);
      expect(HttpServerService.parseRange('bytes=0-', 0), isNull);
    });

    test('inverted range collapses to a single clamped byte', () {
      // 3 clamps up to start 5 — matches the pre-fix clamping semantics.
      expect(HttpServerService.parseRange('bytes=5-3', 10), (5, 5));
    });
  });

  group('A3: WebSocket heartbeat lease', () {
    test('expires silent clients after the timeout, not at its boundary', () {
      final now = DateTime.utc(2026, 10, 30, 12);
      const timeout = Duration(seconds: 45);

      expect(
        HttpServerService.hasHeartbeatExpired(now.subtract(timeout), now),
        isFalse,
      );
      expect(
        HttpServerService.hasHeartbeatExpired(
          now.subtract(timeout + const Duration(milliseconds: 1)),
          now,
        ),
        isTrue,
      );
    });
  });

  group('C3: connection history cap', () {
    test('logAccess caps history at 200 entries', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ServerRepository(await SharedPreferences.getInstance());

      for (var i = 1; i <= 205; i++) {
        await repo.logAccess('10.9.0.$i');
      }

      expect(repo.connectionHistory.length, 200);
      // Most recent first.
      expect(repo.connectionHistory.first.ip, '10.9.0.205');
    });

    test('re-accessing a known IP within 60s is debounced (no duplicate)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ServerRepository(await SharedPreferences.getInstance());

      await repo.logAccess('10.9.9.1');
      final second = await repo.logAccess('10.9.9.1');
      expect(second, isFalse, reason: 'debounced within 60s — no duplicate');
      expect(repo.connectionHistory, hasLength(1));
    });
  });
}
