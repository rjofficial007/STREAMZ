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
  final bool isPaused;
  final DateTime? pausedAt;
  final bool isActive;

  BroadcastStation({
    required this.id,
    required this.name,
    required this.playlist,
    required this.startTime,
    this.isPaused = false,
    this.pausedAt,
    this.isActive = true,
  });

  Duration get totalDuration {
    return playlist.fold<Duration>(Duration.zero, (total, item) => total + Duration(seconds: item.duration));
  }

  BroadcastStation copyWith({
    String? id,
    String? name,
    List<MediaItem>? playlist,
    DateTime? startTime,
    bool? isPaused,
    DateTime? pausedAt,
    bool? isActive,
  }) {
    return BroadcastStation(
      id: id ?? this.id,
      name: name ?? this.name,
      playlist: playlist ?? this.playlist,
      startTime: startTime ?? this.startTime,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: pausedAt ?? this.pausedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'playlist': playlist.map((e) => e.toJson()).toList(),
        'startTime': startTime.toIso8601String(),
        'isPaused': isPaused,
        'pausedAt': pausedAt?.toIso8601String(),
        'isActive': isActive,
      };

  factory BroadcastStation.fromJson(Map<String, dynamic> json) => BroadcastStation(
        id: json['id'],
        name: json['name'],
        playlist: (json['playlist'] as List).map((e) => MediaItem.fromJson(e)).toList(),
        startTime: DateTime.parse(json['startTime']),
        isPaused: json['isPaused'] ?? false,
        pausedAt: json['pausedAt'] != null ? DateTime.parse(json['pausedAt']) : null,
        isActive: json['isActive'] ?? true,
      );
}

class StationPlaybackState {
  final MediaItem item;
  final Duration position;
  final int itemIndex;

  StationPlaybackState({required this.item, required this.position, required this.itemIndex});

  Map<String, dynamic> toJson() => {'item': item.toJson(), 'positionMs': position.inMilliseconds, 'itemIndex': itemIndex};
}
