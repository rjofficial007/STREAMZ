// data/network/udp_discovery.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const _kPort = 8888;
const _kMulticast = '239.1.2.3';
const _kPrefix = 'STREAMZ_HOST:';

class UdpBroadcaster {
  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start(String ip) async {
    if (kIsWeb) return;
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;

      final subnetBroadcast = _subnetBroadcast(ip);
      final data = utf8.encode('$_kPrefix$ip');

      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        _send(data, '255.255.255.255');
        _send(data, subnetBroadcast);
        _send(data, _kMulticast);
      });
    } catch (e) {
      debugPrint('UdpBroadcaster start error: $e');
    }
  }

  void _send(List<int> data, String host) {
    try {
      _socket?.send(data, InternetAddress(host), _kPort);
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
    _timer = null;
    _socket = null;
  }

  static String _subnetBroadcast(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    }
    return '255.255.255.255';
  }
}

class UdpDiscovery {
  RawDatagramSocket? _socket;
  bool _active = false;

  bool get isActive => _active;

  Future<void> start(void Function(String ip) onFound) async {
    if (kIsWeb || _active) return;
    _active = true;
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _kPort, reuseAddress: true);
      try {
        _socket!.joinMulticast(InternetAddress(_kMulticast));
      } catch (e) {
        debugPrint('UdpDiscovery multicast join error: $e');
      }

      _socket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket?.receive();
        if (datagram == null) return;
        final msg = utf8.decode(datagram.data);
        if (msg.startsWith(_kPrefix)) {
          final ip = msg.substring(_kPrefix.length).trim();
          stop();
          onFound(ip);
        }
      });
    } catch (e) {
      debugPrint('UdpDiscovery start error: $e');
      _active = false;
    }
  }

  void stop() {
    if (!_active) return;
    _active = false;
    _socket?.close();
    _socket = null;
  }
}
