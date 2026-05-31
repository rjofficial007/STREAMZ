import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../core/utils/logger.dart';

class NetworkService extends ChangeNotifier {
  String _currentIp = 'Initializing...';
  String get currentIp => _currentIp;

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
          if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.') || addr.address.startsWith('172.')) {
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
