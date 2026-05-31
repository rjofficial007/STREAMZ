// domain/models/media_item.dart

class MediaItem {
  final String id;
  final String title;
  final int duration;
  final String type;
  final String folder;
  final int lastPosition;
  final int lastPlayedTimestamp;
  final bool isBroadcast;

  const MediaItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.type,
    required this.folder,
    this.lastPosition = 0,
    this.lastPlayedTimestamp = 0,
    this.isBroadcast = false,
  });

  bool get isVideo => type == 'video';
  bool get isAudio => type == 'audio';
  bool get isImage => type == 'image';

  double get watchProgress => (duration > 0 && lastPosition > 0) ? lastPosition / duration : 0.0;

  bool get isInProgress => duration > 0 && lastPosition > 30 && watchProgress < 0.95;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'duration': duration,
        'type': type,
        'folder': folder,
        'isBroadcast': isBroadcast,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Unknown',
        duration: (json['duration'] as num?)?.toInt() ?? 0,
        type: json['type']?.toString() ?? 'video',
        folder: json['folder']?.toString() ?? 'Unknown',
        isBroadcast: json['isBroadcast'] ?? false,
      );

  MediaItem copyWith({
    int? lastPosition,
    int? lastPlayedTimestamp,
    bool? isBroadcast,
  }) =>
      MediaItem(
        id: id,
        title: title,
        duration: duration,
        type: type,
        folder: folder,
        lastPosition: lastPosition ?? this.lastPosition,
        lastPlayedTimestamp: lastPlayedTimestamp ?? this.lastPlayedTimestamp,
        isBroadcast: isBroadcast ?? this.isBroadcast,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}