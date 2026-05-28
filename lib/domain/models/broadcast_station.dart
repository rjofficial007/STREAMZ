// domain/models/broadcast_station.dart
// ============================================================================
// STREAMZ — Broadcast Station Model
// ============================================================================

import 'media_item.dart';

class BroadcastStation {
  final String id;
  final String name;
  final List<MediaItem> playlist;
  final DateTime startTime;

  BroadcastStation({
    required this.id,
    required this.name,
    required this.playlist,
    required this.startTime,
  });

  Duration get totalDuration {
    return playlist.fold(
      Duration.zero,
      (total, item) => total + (item.duration ?? Duration.zero),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'playlist': playlist.map((e) => e.toJson()).toList(),
        'startTime': startTime.toIso8601String(),
      };

  factory BroadcastStation.fromJson(Map<String, dynamic> json) => BroadcastStation(
        id: json['id'],
        name: json['name'],
        playlist: (json['playlist'] as List).map((e) => MediaItem.fromJson(e)).toList(),
        startTime: DateTime.parse(json['startTime']),
      );
}

class StationPlaybackState {
  final MediaItem item;
  final Duration position;
  final int itemIndex;

  StationPlaybackState({
    required this.item,
    required this.position,
    required this.itemIndex,
  });

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'positionMs': position.inMilliseconds,
    'itemIndex': itemIndex,
  };
}
