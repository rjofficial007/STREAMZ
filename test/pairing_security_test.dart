// test/pairing_security_test.dart
// ============================================================================
// Runnable checks for the P1 security batch:
//
//  B1 — UDP announcement wire format: STREAMZ_HOST:<ip>[:<token>],
//       backward compatible with legacy (token-less) broadcasters.
//  B3 — Download filename sanitization: network-supplied titles must not
//       escape the save directory or contain platform-illegal characters.
//
// Pure-Dart: no platform channels, runnable under `flutter test`.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:streamz/data/network/udp_discovery.dart';
import 'package:streamz/domain/services/download_service.dart';

void main() {
  group('B1: UDP discovery announcement format', () {
    test('parses ip + token', () {
      final parsed = UdpDiscovery.parseAnnouncement('STREAMZ_HOST:192.168.1.50:QK2MZN47');
      expect(parsed, isNotNull);
      expect(parsed!.$1, '192.168.1.50');
      expect(parsed.$2, 'QK2MZN47');
    });

    test('legacy announcement (no token) still parses', () {
      final parsed = UdpDiscovery.parseAnnouncement('STREAMZ_HOST:192.168.1.50');
      expect(parsed, isNotNull);
      expect(parsed!.$1, '192.168.1.50');
      expect(parsed.$2, isNull);
    });

    test('empty token segment parses as no token', () {
      final parsed = UdpDiscovery.parseAnnouncement('STREAMZ_HOST:10.0.0.7:');
      expect(parsed, isNotNull);
      expect(parsed!.$1, '10.0.0.7');
      expect(parsed.$2, isNull);
    });

    test('non-STREAMZ datagrams are ignored', () {
      expect(UdpDiscovery.parseAnnouncement('OTHER_PROTO:1.2.3.4'), isNull);
      expect(UdpDiscovery.parseAnnouncement('STREAMZ_HOST:'), isNull);
      expect(UdpDiscovery.parseAnnouncement(''), isNull);
    });
  });

  group('B3: download filename sanitization', () {
    test('path separators cannot escape the save directory', () {
      final safe = DownloadService.sanitizeFilename(r'..\..\etc\passwd');
      expect(safe, isNot(contains(r'\')));
      expect(safe, isNot(contains('/')));

      final safe2 = DownloadService.sanitizeFilename('../../secrets/flag.txt');
      expect(safe2, isNot(contains('/')));
      expect(safe2, startsWith('..')); // '..' itself is a harmless literal name now
    });

    test('windows-illegal characters are replaced', () {
      final safe = DownloadService.sanitizeFilename(r'a<b>c:d"e?f*g|h\i');
      expect(safe, 'a_b_c_d_e_f_g_h_i');
    });

    test('control chars and newlines are stripped', () {
      // Each control char becomes its own '_'.
      final safe = DownloadService.sanitizeFilename('line1\nline2\r\x00tab');
      expect(safe, 'line1_line2__tab');
    });

    test('empty titles get a fallback name; all-illegal titles stay safe', () {
      expect(DownloadService.sanitizeFilename(''), 'streamz_download');
      expect(DownloadService.sanitizeFilename('   '), 'streamz_download');
      // Every char replaced — the literal '____' is a harmless filename.
      expect(DownloadService.sanitizeFilename(':://'), '____');
    });

    test('overly long titles are truncated', () {
      final long = 'x' * 500;
      expect(DownloadService.sanitizeFilename(long).length, lessThanOrEqualTo(150));
    });

    test('normal unicode titles pass through', () {
      expect(
        DownloadService.sanitizeFilename('Füße & Größen — 4K (2026).mp4'),
        'Füße & Größen — 4K (2026).mp4',
      );
    });
  });
}
