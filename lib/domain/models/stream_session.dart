// domain/models/stream_session.dart

class StreamSession {
  final String sessionId;
  final String clientId;
  final String title;
  final double progress;
  final String mediaType;
  final DateTime lastUpdated;

  const StreamSession({required this.sessionId, required this.clientId, required this.title, required this.progress, required this.mediaType, required this.lastUpdated});

  bool get isStale => DateTime.now().difference(lastUpdated).inSeconds > 15;

  StreamSession copyWith({double? progress, DateTime? lastUpdated}) =>
      StreamSession(sessionId: sessionId, clientId: clientId, title: title, progress: progress ?? this.progress, mediaType: mediaType, lastUpdated: lastUpdated ?? this.lastUpdated);
}
