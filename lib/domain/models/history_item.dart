// domain/models/history_item.dart
import 'package:streamz/domain/models/media_item.dart';

class HistoryItem {

  HistoryItem({
    required this.media,
    required this.timestamp,
    this.clientId,
    this.clientIp,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    media: MediaItem.fromJson(json['media']),
    timestamp: DateTime.parse(json['timestamp']),
    clientId: json['clientId'],
    clientIp: json['clientIp'],
  );
  final MediaItem media;
  final DateTime timestamp;
  final String? clientId; // Used on server to identify who viewed it
  final String? clientIp;

  Map<String, dynamic> toJson() => {
    'media': media.toJson(),
    'timestamp': timestamp.toIso8601String(),
    if (clientId != null) 'clientId': clientId,
    if (clientIp != null) 'clientIp': clientIp,
  };
}
