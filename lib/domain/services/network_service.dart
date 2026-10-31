import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:streamz/core/utils/logger.dart';

class NetworkService extends ChangeNotifier {
  static const MethodChannel _networkInfoChannel = MethodChannel(
    'streamz/network_info',
  );

  late final StreamController<Object?> _networkChangeController =
      StreamController<Object?>.broadcast(
        onListen: _startPlatformNetworkChanges,
        onCancel: _stopPlatformNetworkChanges,
      );
  StreamSubscription<dynamic>? _platformNetworkSubscription;
  bool _disposed = false;

  String _currentIp = 'Initializing...';
  String _currentInterfaceName = '';
  String get currentIp => _currentIp;
  String get currentInterfaceName => _currentInterfaceName;
  Stream<Object?> get networkChanges => _networkChangeController.stream;

  void _startPlatformNetworkChanges() {
    if (_disposed || kIsWeb || !Platform.isAndroid) return;
    _platformNetworkSubscription = const EventChannel('streamz/network_changes')
        .receiveBroadcastStream()
        .listen(
          (event) {
            if (_disposed || _networkChangeController.isClosed) return;
            if (event is Map && event['initial'] == true) return;
            _networkChangeController.add(event);
          },
          onError: (Object error) {
            logger.w('Android network listener error', error: error);
          },
        );
  }

  void _stopPlatformNetworkChanges() {
    unawaited(_platformNetworkSubscription?.cancel());
    _platformNetworkSubscription = null;
  }

  /// True for RFC1918 IPv4 addresses, with the 172.16/12 range checked
  /// precisely so unrelated 172.x addresses are not treated as LAN hosts.
  static bool isLanIp(String address) {
    final parsed = InternetAddress.tryParse(address);
    if (parsed == null || parsed.type != InternetAddressType.IPv4) return false;
    final bytes = parsed.rawAddress;
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }

  @visibleForTesting
  static ({String address, String interfaceName})? activeLanRoute(
    Map<dynamic, dynamic>? networkInfo,
  ) {
    if (networkInfo?['isLocalTransport'] != true) return null;
    final addresses = networkInfo?['addresses'];
    if (addresses is! Iterable) return null;
    final interfaceName = networkInfo?['interfaceName'];
    for (final value in addresses) {
      if (value is String) {
        final parsed = InternetAddress.tryParse(value);
        if (parsed != null && isLanIp(value)) {
          return (
            address: parsed.address,
            interfaceName: interfaceName is String ? interfaceName : '',
          );
        }
      }
    }
    return null;
  }

  @visibleForTesting
  static String? activeLanIp(Map<dynamic, dynamic>? networkInfo) =>
      activeLanRoute(networkInfo)?.address;

  Future<bool> ensureLocalNetworkAccess() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 37) return true;
      return (await Permission.accessLocalNetwork.request()).isGranted;
    } catch (error) {
      logger.e('Local network permission request failed', error: error);
      return false;
    }
  }

  Future<void> updateIp() async {
    _currentIp = await detectIp();
    notifyListeners();
  }

  Future<String> detectIp() async {
    if (kIsWeb) return '127.0.0.1';
    _currentInterfaceName = '';

    if (Platform.isAndroid) {
      try {
        final networkInfo = await _networkInfoChannel
            .invokeMapMethod<String, dynamic>('getActiveNetworkInfo');
        final activeRoute = activeLanRoute(networkInfo);
        if (activeRoute != null) {
          _currentInterfaceName = activeRoute.interfaceName;
          return activeRoute.address;
        }
      } catch (error) {
        logger.w(
          'Active Android route lookup failed; scanning interfaces',
          error: error,
        );
      }
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final candidates =
          <({int score, String address, String interfaceName})>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback || addr.isLinkLocal || !isLanIp(addr.address)) {
            continue;
          }
          final score = interfaceScore(iface.name);
          if (score < 0) continue;
          candidates.add((
            score: score,
            address: addr.address,
            interfaceName: iface.name,
          ));
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.score.compareTo(a.score));
        _currentInterfaceName = candidates.first.interfaceName;
        return candidates.first.address;
      }
    } catch (e) {
      logger.e('Network interface detection error', error: e);
    }

    return 'No Network';
  }

  @visibleForTesting
  static int interfaceScore(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('vpn') ||
        normalized.contains('cellular') ||
        normalized.contains('mobile') ||
        normalized.contains('rmnet') ||
        normalized.contains('ccmni') ||
        normalized.contains('pdp') ||
        normalized.contains('wwan') ||
        normalized.contains('tun') ||
        normalized.contains('tap') ||
        normalized.contains('wireguard') ||
        normalized.startsWith('wg') ||
        normalized.contains('tailscale') ||
        normalized.contains('zerotier') ||
        normalized.contains('virtual') ||
        normalized.contains('docker') ||
        normalized.startsWith('veth') ||
        normalized.startsWith('br-') ||
        normalized.startsWith('virbr') ||
        normalized.contains('vmnet') ||
        normalized.contains('bridge') ||
        normalized.contains('hyper-v')) {
      return -100;
    }
    if (normalized.contains('wifi') ||
        normalized.contains('wi-fi') ||
        normalized.contains('wlan')) {
      return 30;
    }
    if (normalized.contains('ethernet') ||
        normalized.startsWith('eth') ||
        normalized.startsWith('en')) {
      return 20;
    }
    return 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPlatformNetworkChanges();
    unawaited(_networkChangeController.close());
    super.dispose();
  }
}
