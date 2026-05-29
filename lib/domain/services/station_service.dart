// domain/services/station_service.dart
// ============================================================================
// STREAMZ — Station Management Service
// ============================================================================

import '../models/broadcast_station.dart';

class StationService {
  StationPlaybackState? getPlaybackState(BroadcastStation station) {
    if (station.playlist.isEmpty) return null;

    final totalDuration = station.totalDuration;
    if (totalDuration == Duration.zero) return null;

    final now = DateTime.now();
    final elapsed = now.difference(station.startTime);
    final totalMs = totalDuration.inMilliseconds;

    // Use modulo to find where we are in the repeating playlist cycle.
    final currentCycleMs = elapsed.inMilliseconds % totalMs;

    int accumulatedMs = 0;
    for (int i = 0; i < station.playlist.length; i++) {
      final item = station.playlist[i];
      // MediaItem.duration is in seconds, convert to ms for comparison.
      final itemMs = item.duration * 1000;

      if (currentCycleMs < accumulatedMs + itemMs) {
        return StationPlaybackState(
          item: item,
          position: Duration(milliseconds: currentCycleMs - accumulatedMs),
          itemIndex: i,
        );
      }
      accumulatedMs += itemMs;
    }

    // Fallback to first item if something went wrong
    return StationPlaybackState(item: station.playlist.first, position: Duration.zero, itemIndex: 0);
  }
}
