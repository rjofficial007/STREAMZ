import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/data/network/udp_discovery.dart';

void main() {
  group('mDNS LAN address selection', () {
    test('accepts all RFC1918 IPv4 ranges', () {
      expect(UdpDiscovery.isLanIpv4Address('10.20.30.40'), isTrue);
      expect(UdpDiscovery.isLanIpv4Address('172.16.0.1'), isTrue);
      expect(UdpDiscovery.isLanIpv4Address('172.31.255.254'), isTrue);
      expect(UdpDiscovery.isLanIpv4Address('192.168.1.2'), isTrue);
    });

    test('rejects public, out-of-range, and non-IPv4 addresses', () {
      expect(UdpDiscovery.isLanIpv4Address('172.15.0.1'), isFalse);
      expect(UdpDiscovery.isLanIpv4Address('172.32.0.1'), isFalse);
      expect(UdpDiscovery.isLanIpv4Address('192.169.1.2'), isFalse);
      expect(UdpDiscovery.isLanIpv4Address('8.8.8.8'), isFalse);
      expect(UdpDiscovery.isLanIpv4Address('fe80::1'), isFalse);
    });

    test('returns every address for the remembered mDNS host identity', () {
      expect(
        UdpDiscovery.mdnsAddressesForHost(const [
          DiscoveredHost(
            ip: '192.168.1.8',
            name: 'Hestia',
            hostId: 'server-a',
            viaMdns: true,
          ),
          DiscoveredHost(
            ip: '10.0.0.8',
            name: 'Hestia',
            hostId: 'server-a',
            viaMdns: true,
          ),
          DiscoveredHost(
            ip: '192.168.1.9',
            name: 'Hestia',
            hostId: 'server-b',
            viaMdns: true,
          ),
          DiscoveredHost(ip: '192.168.1.10', name: 'Hestia'),
        ], 'server-a'),
        ['192.168.1.8', '10.0.0.8'],
      );
    });
  });
}
