import 'package:streamz/core/constants/app_strings.dart';

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
      'The host or Wi-Fi stopped responding. ${AppStrings.appTitle} will retry '
      'and resume near your last position. Check that the host is running on '
      'the same network.',
    PlaybackIssueKind.codec =>
      'This file may use a format unsupported by this device or browser. Try another file or a different playback device.',
    PlaybackIssueKind.device =>
      'Playback was blocked. Choose Retry; check autoplay or media permissions if it happens again.',
    PlaybackIssueKind.unknown =>
      'Check the host connection, then retry. If other files play, this file may use an unsupported format.',
  };
}
