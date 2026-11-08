// domain/models/broadcast_station.dart
// ============================================================================
// STREAMZ — Broadcast Station Model
// ============================================================================

import 'package:streamz/domain/models/media_item.dart';

class BroadcastStation {

  BroadcastStation({
    required this.id,
    required this.name,
    required this.playlist,
    required this.startTime,
    this.isPaused = false,
    this.pausedAt,
    this.isActive = true,
    this.nowPlaying,
  });

  factory BroadcastStation.fromJson(Map<String, dynamic> json) => BroadcastStation(
        id: json['id'],
        name: json['name'],
        playlist: json['playlist'] != null ? (json['playlist'] as List).map((e) => MediaItem.fromJson(e)).toList() : [],
        startTime: DateTime.parse(json['startTime']),
        isPaused: json['isPaused'] ?? false,
        pausedAt: json['pausedAt'] != null ? DateTime.parse(json['pausedAt']) : null,
        isActive: json['isActive'] ?? true,
        nowPlaying: json['nowPlaying'] != null ? StationPlaybackState.fromJson(json['nowPlaying']) : null,
      );
  final String id;
  final String name;
  final List<MediaItem> playlist;
  final DateTime startTime;
  final bool isPaused;
  final DateTime? pausedAt;
  final bool isActive;
  final StationPlaybackState? nowPlaying;

  Duration get totalDuration => playlist.fold<Duration>(Duration.zero, (total, item) => total + Duration(seconds: item.duration));

  BroadcastStation copyWith({
    String? id,
    String? name,
    List<MediaItem>? playlist,
    DateTime? startTime,
    bool? isPaused,
    DateTime? pausedAt,
    bool? isActive,
    StationPlaybackState? nowPlaying,
  }) => BroadcastStation(
      id: id ?? this.id,
      name: name ?? this.name,
      playlist: playlist ?? this.playlist,
      startTime: startTime ?? this.startTime,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: pausedAt ?? this.pausedAt,
      isActive: isActive ?? this.isActive,
      nowPlaying: nowPlaying ?? this.nowPlaying,
    );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'playlist': playlist.map((e) => e.toJson()).toList(),
        'startTime': startTime.toIso8601String(),
        'isPaused': isPaused,
        'pausedAt': pausedAt?.toIso8601String(),
        'isActive': isActive,
        if (nowPlaying != null) 'nowPlaying': nowPlaying!.toJson(),
      };
}

class StationPlaybackState {

  StationPlaybackState({required this.item, required this.position, required this.itemIndex});

  factory StationPlaybackState.fromJson(Map<String, dynamic> json) => StationPlaybackState(
    item: MediaItem.fromJson(json['item']),
    position: Duration(milliseconds: json['positionMs'] ?? 0),
    itemIndex: json['itemIndex'] ?? 0,
  );
  final MediaItem item;
  final Duration position;
  final int itemIndex;

  Map<String, dynamic> toJson() => {'item': item.toJson(), 'positionMs': position.inMilliseconds, 'itemIndex': itemIndex};
}

class StationJoinResponse {

  StationJoinResponse({
    required this.playlist,
    required this.itemIndex,
    required this.position,
    required this.isPaused,
    this.syncRole = '',
    this.stationRevision = -1,
  });

  factory StationJoinResponse.fromJson(Map<String, dynamic> json) => StationJoinResponse(
    playlist: (json['playlist'] as List).map((e) => MediaItem.fromJson(e)).toList(),
    itemIndex: json['itemIndex'] ?? 0,
    position: Duration(milliseconds: json['positionMs'] ?? 0),
    isPaused: json['isPaused'] ?? false,
    syncRole: json['syncRole']?.toString() ?? '',
    stationRevision: (json['stationRevision'] as num?)?.toInt() ?? -1,
  );
  final List<MediaItem> playlist;
  final int itemIndex;
  final Duration position;
  final bool isPaused;

  /// [A3] Sync role elected by the server: 'master' | 'slave' | '' (non-participant).
  final String syncRole;
  final int stationRevision;
}
