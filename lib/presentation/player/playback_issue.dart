enum PlaybackIssueKind { connection, codec, device, unknown }

class PlaybackIssue {
  const PlaybackIssue(this.kind);

  // ponytail: native and browser player errors do not share structured codes;
  // unusual vendor messages may be misclassified. Upgrade by mapping platform
  // error codes and HTTP response status into these same four categories.
  factory PlaybackIssue.fromMessage(String message) {
    final value = message.toLowerCase();
    bool containsAny(Iterable<String> terms) =>
        terms.any(value.contains);

    if (containsAny([
      'notallowederror',
      'not allowed',
      'autoplay',
      'permission denied',
      'user gesture',
    ])) {
      return const PlaybackIssue(PlaybackIssueKind.device);
    }
    if (containsAny([
      'codec',
      'decoder',
      'decode',
      'demux',
      'unsupported',
      'src_not_supported',
      'format',
      'invalid data',
      'media_err_decode',
    ])) {
      return const PlaybackIssue(PlaybackIssueKind.codec);
    }
    if (containsAny([
      'network',
      'connection',
      'socket',
      'timed out',
      'timeout',
      'unreachable',
      'refused',
      'broken pipe',
      'reset by peer',
      'http',
      'dns',
      'media_err_network',
    ])) {
      return const PlaybackIssue(PlaybackIssueKind.connection);
    }
    return const PlaybackIssue(PlaybackIssueKind.unknown);
  }

  final PlaybackIssueKind kind;

  bool get canAutoRetry => kind == PlaybackIssueKind.connection;

  String get title => switch (kind) {
    PlaybackIssueKind.connection => 'Connection interrupted',
    PlaybackIssueKind.codec => 'This media may not be supported',
    PlaybackIssueKind.device => 'Playback was blocked by this device',
    PlaybackIssueKind.unknown => 'Playback stopped unexpectedly',
  };

  String get description => switch (kind) {
    PlaybackIssueKind.connection =>
      'The media host or network stopped responding. STREAMZ will retry and continue near your last position. Check that both devices are on the same Wi-Fi and the host is still running.',
    PlaybackIssueKind.codec =>
      'The file format or codec may not be supported by this device or browser. Try another file, or play this one on a device with broader codec support.',
    PlaybackIssueKind.device =>
      'The browser or device blocked playback. Choose Retry to start it again; on the Web, check autoplay and media permissions if it keeps happening.',
    PlaybackIssueKind.unknown =>
      'Check that the media host and network are reachable, then try another file. If other files play, this file may use an unsupported format or codec.',
  };
}
