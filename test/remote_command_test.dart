// test/remote_command_test.dart
// ============================================================================
// Pins the server<->client wire contract for the two 'media' command payloads
// that previously disagreed between sender and receiver:
//
//  1. media/teleport — ServerViewModel.teleport() sends 'position' (seconds);
//     the client (PlayerService) must read it. 'progress' kept as legacy key.
//  2. media/play     — NOC "play on client" sends the full MediaItem JSON map
//     (not a title string); the client must be able to decode it.
//
// These are pure-Dart model tests: no platform channels, runnable in `flutter test`.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/models/remote_command.dart';

void main() {
  group('server<->client wire contract', () {
    test('teleport payload: position key as sent by ServerViewModel resolves on the client', () {
      // Exact payload shape of ServerViewModel.teleport():
      //   {'mediaId': ..., 'position': session.position, 'mediaType': ...}
      final cmd = RemoteCommand.fromJson({
        'type': 'media',
        'action': 'teleport',
        'senderId': 'SERVER',
        'value': {'mediaId': 'A1', 'position': 42, 'mediaType': 'audio'},
      });

      expect(cmd.type, 'media');
      expect(cmd.action, 'teleport');
      expect(cmd.value, isA<Map<String, dynamic>>());

      final data = cmd.value as Map<String, dynamic>;
      // Same expression PlayerService uses to read the offset.
      final pos = (data['position'] ?? data['progress']) as num?;
      expect(pos, 42);

      // mediaType must survive the round trip (client no longer hardcodes 'video').
      expect(data['mediaType']?.toString(), 'audio');
    });

    test('teleport payload: legacy progress key still resolves', () {
      final data = <String, dynamic>{'mediaId': 'A1', 'progress': 17};
      final pos = (data['position'] ?? data['progress']) as num?;
      expect(pos, 17);
    });

    test('play payload: full MediaItem map round-trips (NOC play-on-client)', () {
      const item = MediaItem(id: '9', title: 'Clip', duration: 99, type: 'video', folder: 'F');
      // Shape of the broadcast payload: jsonEncode of item.toJson().
      final cmd = RemoteCommand.fromJson({
        'type': 'media',
        'action': 'play',
        'senderId': 'SERVER',
        'value': item.toJson(),
      });

      expect(cmd.value, isA<Map<String, dynamic>>());
      final decoded = MediaItem.fromJson(cmd.value as Map<String, dynamic>);
      expect(decoded.id, '9');
      expect(decoded.title, 'Clip');
      expect(decoded.duration, 99);
      expect(decoded.isVideo, isTrue);
    });

    test('play payload: string query stays a string (dashboard CLI /play)', () {
      final cmd = RemoteCommand.fromJson({
        'type': 'media',
        'action': 'play',
        'senderId': 'SERVER',
        'value': 'big buck bunny',
      });
      expect(cmd.value, 'big buck bunny');
    });
  });
}
