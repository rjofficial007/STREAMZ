// test/station_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/services/station_service.dart';

void main() {
  group('StationService Tests', () {
    final service = StationService();
    
    final items = [
      const MediaItem(id: '1', title: 'Video 1', duration: 10, type: 'video', folder: 'test'), // 10s
      const MediaItem(id: '2', title: 'Video 2', duration: 20, type: 'video', folder: 'test'), // 20s
      const MediaItem(id: '3', title: 'Video 3', duration: 30, type: 'video', folder: 'test'), // 30s
    ];
    // Total duration: 60s

    test('calculates correct item and offset at start', () {
      final station = BroadcastStation(
        id: '1',
        name: 'Test',
        playlist: items,
        startTime: DateTime.now(),
      );

      final state = service.getPlaybackState(station);
      expect(state?.item.id, '1');
      expect(state?.position.inMilliseconds, lessThan(500)); // Should be almost 0
    });

    test('calculates correct item in middle of playlist', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 25));
      final station = BroadcastStation(
        id: '1',
        name: 'Test',
        playlist: items,
        startTime: startTime,
      );

      final state = service.getPlaybackState(station);
      // 25s elapsed: 
      // 0-10s: Video 1
      // 10-30s: Video 2 (elapsed 15s into Video 2)
      expect(state?.item.id, '2');
      expect(state?.position.inSeconds, 15);
    });

    test('loops correctly after total duration', () {
      // Elapsed 75s (60s total + 15s)
      final startTime = DateTime.now().subtract(const Duration(seconds: 75));
      final station = BroadcastStation(
        id: '1',
        name: 'Test',
        playlist: items,
        startTime: startTime,
      );

      final state = service.getPlaybackState(station);
      // 15s into second cycle:
      // 0-10s: Video 1
      // 10-30s: Video 2 (elapsed 5s into Video 2)
      expect(state?.item.id, '2');
      expect(state?.position.inSeconds, 5);
    });
   group('Serialization Tests', () {
      test('BroadcastStation to/from JSON', () {
        final station = BroadcastStation(
          id: '1',
          name: 'Test',
          playlist: items,
          startTime: DateTime(2024, 1, 1),
        );
        final json = station.toJson();
        final fromJson = BroadcastStation.fromJson(json);
        
        expect(fromJson.id, station.id);
        expect(fromJson.name, station.name);
        expect(fromJson.playlist.length, station.playlist.length);
        expect(fromJson.startTime, station.startTime);
      });
    });
  });
}
