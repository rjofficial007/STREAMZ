import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/domain/services/network_service.dart';

void main() {
  group('LAN interface selection', () {
    test('uses the active Wi-Fi or Ethernet address when available', () {
      expect(
        NetworkService.activeLanIp({
          'isLocalTransport': true,
          'interfaceName': 'wlan0',
          'addresses': ['fe80::1234', '192.168.4.20'],
        }),
        '192.168.4.20',
      );
      expect(
        NetworkService.activeLanRoute({
          'isLocalTransport': true,
          'interfaceName': 'wlan0',
          'addresses': ['192.168.4.20'],
        }),
        (address: '192.168.4.20', interfaceName: 'wlan0'),
      );
      expect(
        NetworkService.activeLanIp({
          'isLocalTransport': false,
          'addresses': ['10.0.0.5'],
        }),
        isNull,
      );
    });

    test('prefers Wi-Fi, then Ethernet, and retains an unknown fallback', () {
      expect(NetworkService.interfaceScore('wlan0'), greaterThan(20));
      expect(NetworkService.interfaceScore('Wi-Fi'), greaterThan(0));
      expect(NetworkService.interfaceScore('eth0'), greaterThan(0));
      expect(NetworkService.interfaceScore('en0'), greaterThan(0));
      expect(NetworkService.interfaceScore('lan0'), 0);
    });

    test('rejects common VPN and virtual interfaces', () {
      for (final name in [
        'tun0',
        'tap0',
        'wg0',
        'rmnet_data0',
        'ccmni0',
        'wwan0',
        'Cellular',
        'tailscale0',
        'zerotier0',
        'vEthernet (Default Switch)',
        'docker0',
      ]) {
        expect(NetworkService.interfaceScore(name), lessThan(0), reason: name);
      }
    });
  });
}
