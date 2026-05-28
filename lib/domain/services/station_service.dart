// domain/services/station_service.dart
// ============================================================================
// STREAMZ — Station Management Service
// ============================================================================

import '../models/broadcast_station.dart';
import '../models/media_item.dart';

class StationService {
  StationPlaybackState? getPlaybackState(BroadcastStation station) {
    if (station.playlist.isEmpty) return null;

    final totalDuration = station.totalDuration;
    if (totalDuration == Duration.zero) return null;

    final now = DateTime.now();
    final elapsed = now.difference(station.startTime);
    final totalMs = totalDuration.inMilliseconds;
    final currentCycleMs = elapsed.inMilliseconds % totalMs;

    int accumulatedMs = 0;
    for (int i = 0; i < station.playlist.length; i++) {
      final item = station.playlist[i];
      final itemMs = (item.duration ?? Duration.zero).inMilliseconds;
      
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
    return StationPlaybackState(
      item: station.playlist.first,
      position: Duration.zero,
      itemIndex: 0,
    );
  }
}
