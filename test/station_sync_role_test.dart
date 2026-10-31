// test/station_sync_role_test.dart
// ============================================================================
// Runnable check for A3:
// StationJoinResponse must carry the server-elected sync role so a joining
// client can apply master/slave sync mode.
//
// Pure-Dart: no platform channels, runnable under `flutter test`.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';

void main() {
  group('A3: station sync role contract', () {
    test('StationJoinResponse round-trips syncRole', () {
      const item = MediaItem(id: '1', title: 'A', duration: 10, type: 'video', folder: 'f');
      final res = StationJoinResponse.fromJson({
        'playlist': [item.toJson()],
        'itemIndex': 0,
        'positionMs': 5000,
        'isPaused': false,
        'syncRole': 'master',
        'stationRevision': 7,
      });
      expect(res.syncRole, 'master');
      expect(res.stationRevision, 7);
    });

    test('StationJoinResponse defaults to no role (web / legacy server)', () {
      const item = MediaItem(id: '1', title: 'A', duration: 10, type: 'video', folder: 'f');
      final res = StationJoinResponse.fromJson({
        'playlist': [item.toJson()],
        'itemIndex': 0,
        'positionMs': 0,
        'isPaused': false,
      });
      expect(res.syncRole, '');
      expect(res.stationRevision, -1);
    });
  });
}
