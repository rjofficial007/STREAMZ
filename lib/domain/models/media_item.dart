// domain/models/media_item.dart

class MediaItem {

  const MediaItem({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    required this.duration,
    required this.type,
    required this.folder,
    this.lastPosition = 0,
    this.lastPlayedTimestamp = 0,
    this.isBroadcast = false,
    this.metadata = const {},
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Unknown',
        artist: json['artist']?.toString(),
        album: json['album']?.toString(),
        duration: (json['duration'] as num?)?.toInt() ?? 0,
        type: json['type']?.toString() ?? 'video',
        folder: json['folder']?.toString() ?? 'Unknown',
        isBroadcast: json['isBroadcast'] ?? false,
        metadata: _parseMetadata(json['metadata']),
      );

  // [FIX C6] A non-string metadata value (or a non-map payload) must not
  // throw and take down the parse of the whole media list — stringify
  // values, skip nulls.
  static Map<String, String> _parseMetadata(dynamic raw) {
    if (raw is! Map) return {};
    return Map.fromEntries(
      raw.entries
          .where((e) => e.value != null)
          .map((e) => MapEntry(e.key.toString(), e.value.toString())),
    );
  }
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final int duration;
  final String type;
  final String folder;
  final int lastPosition;
  final int lastPlayedTimestamp;
  final bool isBroadcast;
  final Map<String, String> metadata;

  bool get isVideo => type.toLowerCase() == 'video';
  bool get isAudio => type.toLowerCase() == 'audio';
  bool get isImage => type.toLowerCase() == 'image';

  double get watchProgress => (duration > 0 && lastPosition > 0) ? lastPosition / duration : 0.0;

  bool get isInProgress => duration > 0 && lastPosition > 30 && watchProgress < 0.95;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'duration': duration,
        'type': type,
        'folder': folder,
        'isBroadcast': isBroadcast,
        'metadata': metadata,
      };

  MediaItem copyWith({
    String? title,
    String? artist,
    String? album,
    int? duration,
    int? lastPosition,
    int? lastPlayedTimestamp,
    bool? isBroadcast,
    Map<String, String>? metadata,
  }) =>
      MediaItem(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        duration: duration ?? this.duration,
        type: type,
        folder: folder,
        lastPosition: lastPosition ?? this.lastPosition,
        lastPlayedTimestamp: lastPlayedTimestamp ?? this.lastPlayedTimestamp,
        isBroadcast: isBroadcast ?? this.isBroadcast,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem &&
          id == other.id &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, title, artist, album, type);
}
