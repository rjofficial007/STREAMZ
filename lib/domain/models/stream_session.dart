// domain/models/stream_session.dart

class StreamSession {
  final String sessionId;
  final String clientId;
  final String title;
  final String? mediaId;
  final double progress;
  final int? position; // Absolute seconds
  final String mediaType;
  final String? snapshot; // Base64 low-res image
  final List<String>? vibeColors; // Hex codes
  final DateTime lastUpdated;

  const StreamSession({required this.sessionId, required this.clientId, required this.title, this.mediaId, required this.progress, this.position, required this.mediaType, this.snapshot, this.vibeColors, required this.lastUpdated});

  bool get isStale => DateTime.now().difference(lastUpdated).inSeconds > 15;

  StreamSession copyWith({double? progress, int? position, String? snapshot, List<String>? vibeColors, DateTime? lastUpdated}) => StreamSession(
      sessionId: sessionId,
      clientId: clientId,
      title: title,
      mediaId: mediaId,
      progress: progress ?? this.progress,
      position: position ?? this.position,
      mediaType: mediaType,
      snapshot: snapshot ?? this.snapshot,
      vibeColors: vibeColors ?? this.vibeColors,
      lastUpdated: lastUpdated ?? this.lastUpdated);
}
