import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:streamz/core/utils/logger.dart';

class NetworkService extends ChangeNotifier {
  String _currentIp = 'Initializing...';
  String get currentIp => _currentIp;

  /// [FIX C10] Single source of truth for "is this a private LAN IPv4".
  /// Shared by IP detection and the lifecycle watchdog (which previously
  /// used a narrower check that missed 172.x addresses entirely).
  static bool isLanIp(String addr) =>
      addr.startsWith('192.168.') || addr.startsWith('10.') || addr.startsWith('172.');

  Future<void> updateIp() async {
    _currentIp = await detectIp();
    notifyListeners();
  }

  Future<String> detectIp() async {
    if (kIsWeb) return '127.0.0.1';
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      String? best;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          // [FIX C10] Shared LAN-IP predicate — NetworkService and the
          // ServerLifecycleService watchdog used to disagree (the watchdog
          // missed 172.x entirely, so IP changes on those networks were
          // never noticed). One helper, one definition.
          if (isLanIp(addr.address)) {
            return addr.address;
          }
          best ??= addr.address;
        }
      }
      if (best != null) return best;
    } catch (e) {
      logger.e('Network interface detection error', error: e);
    }

    try {
      final info = NetworkInfo();
      return await info.getWifiIP() ?? 'No Network';
    } catch (e) {
      logger.e('WiFi IP detection error', error: e);
      return 'No Network';
    }
  }
}
