import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/utils/logger.dart';

const _kPort = 8888;
const _kHttpPort = 8080;
const _kMulticast = '239.1.2.3';
const _kPrefix = 'STREAMZ_HOST:';
const _kMdnsServiceType = '_streamz._tcp';

class DiscoveredHost {
  const DiscoveredHost({
    required this.ip,
    required this.name,
    this.pairingToken,
    this.viaMdns = false,
    this.hostId,
  });

  final String ip;
  final String name;
  final String? pairingToken;
  final bool viaMdns;
  final String? hostId;
}

class UdpBroadcaster {
  RawDatagramSocket? _socket;
  Timer? _timer;
  BonsoirBroadcast? _mdnsBroadcast;
  final String _hostId =
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(1 << 32).toRadixString(36)}';

  Future<void> start(String ip, [String? token]) async {
    if (kIsWeb || _timer != null || _socket != null || _mdnsBroadcast != null) {
      return;
    }

    try {
      final broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: AppStrings.appTitle,
          type: _kMdnsServiceType,
          port: _kHttpPort,
          attributes: {'version': '1', 'hostId': _hostId},
        ),
      );
      _mdnsBroadcast = broadcast;
      await broadcast.initialize();
      await broadcast.start();
    } catch (error) {
      _mdnsBroadcast = null;
      logger.w(
        'mDNS broadcast unavailable; UDP fallback remains active',
        error: error,
      );
    }

    if (ip == 'No Network') return;
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;

      // Keep the existing UDP announcement as a compatibility fallback.
      final payload = (token == null || token.isEmpty)
          ? '$_kPrefix$ip'
          : '$_kPrefix$ip:$token';
      final data = utf8.encode(payload);
      _sendFallback(data);
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        _sendFallback(data);
      });
    } catch (error) {
      logger.e('UDP fallback broadcaster start error', error: error);
    }
  }

  void _sendFallback(List<int> data) {
    _send(data, '255.255.255.255');
    _send(data, _kMulticast);
  }

  void _send(List<int> data, String host) {
    try {
      _socket?.send(data, InternetAddress(host), _kPort);
    } catch (_) {}
  }

  Future<void> stop() async {
    _timer?.cancel();
    _socket?.close();
    _timer = null;
    _socket = null;
    final broadcast = _mdnsBroadcast;
    _mdnsBroadcast = null;
    if (broadcast != null) {
      try {
        await broadcast.stop();
      } catch (error) {
        logger.w('mDNS broadcast stop failed', error: error);
      }
    }
  }
}

class UdpDiscovery {
  RawDatagramSocket? _socket;
  BonsoirDiscovery? _mdnsDiscovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _mdnsSubscription;
  Timer? _scanTimeout;
  Timer? _udpFallbackDelay;
  Stopwatch? _scanStopwatch;
  bool _active = false;
  bool _onFoundCalled = false;
  int _generation = 0;
  String? _failure;
  void Function(String ip, String? token)? _onFound;
  void Function(List<DiscoveredHost> hosts)? _onHostsChanged;
  void Function()? _onFinished;
  final Map<String, DiscoveredHost> _hosts = {};

  bool get isActive => _active;
  String? get failure => _failure;
  List<DiscoveredHost> get hosts => List.unmodifiable(_hosts.values);

  static (String ip, String? token)? parseAnnouncement(String msg) {
    if (!msg.startsWith(_kPrefix)) return null;
    final parts = msg.substring(_kPrefix.length).trim().split(':');
    if (parts.isEmpty || parts[0].isEmpty) return null;
    final token = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    return (parts[0], token);
  }

  static List<String> mdnsAddressesForHost(
    List<DiscoveredHost> hosts,
    String hostId,
  ) => hosts
      .where((host) => host.viaMdns && host.hostId == hostId)
      .map((host) => host.ip)
      .toSet()
      .toList(growable: false);

  Future<void> start(
    void Function(String ip, String? token) onFound, {
    void Function(List<DiscoveredHost> hosts)? onHostsChanged,
    void Function()? onFinished,
  }) async {
    if (kIsWeb || _active) return;
    _active = true;
    _hosts.clear();
    _failure = null;
    _scanStopwatch = Stopwatch()..start();
    _onFound = onFound;
    _onFoundCalled = false;
    _onHostsChanged = onHostsChanged;
    _onFinished = onFinished;
    final generation = ++_generation;
    _scanTimeout = Timer(
      const Duration(seconds: 10),
      () => _finish(generation),
    );
    _udpFallbackDelay = Timer(const Duration(seconds: 3), () {
      unawaited(_startUdpFallback(generation));
    });

    try {
      final discovery = BonsoirDiscovery(type: _kMdnsServiceType);
      _mdnsDiscovery = discovery;
      await discovery.initialize();
      if (!_active || generation != _generation) return;
      _mdnsSubscription = discovery.eventStream!.listen(
        (event) => _handleMdnsEvent(discovery, event),
        onError: (Object error) {
          logger.w('mDNS discovery event error', error: error);
          unawaited(_startUdpFallback(generation));
        },
      );
      await discovery.start();
    } catch (error) {
      logger.w(
        'mDNS discovery unavailable; starting UDP fallback',
        error: error,
      );
      await _startUdpFallback(generation);
    }
  }

  void _handleMdnsEvent(
    BonsoirDiscovery discovery,
    BonsoirDiscoveryEvent event,
  ) {
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      final service = event.service;
      unawaited(service.resolve(discovery.serviceResolver));
      return;
    }
    if (event is! BonsoirDiscoveryServiceResolvedEvent) return;

    final service = event.service;
    for (final address in service.hostAddresses) {
      final parsed = InternetAddress.tryParse(address);
      if (parsed?.type != InternetAddressType.IPv4 ||
          !isLanIpv4Address(address)) {
        continue;
      }
      _addHost(
        parsed!.address,
        name: service.name,
        hostId: service.attributes['hostId'],
        viaMdns: true,
      );
    }
  }

  @visibleForTesting
  static bool isLanIpv4Address(String address) {
    final parsed = InternetAddress.tryParse(address);
    if (parsed?.type != InternetAddressType.IPv4) return false;
    final bytes = parsed!.rawAddress;
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }

  Future<void> _startUdpFallback(int generation) async {
    if (!_active || generation != _generation || _socket != null) return;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _kPort,
        reuseAddress: true,
      );
      if (!_active || generation != _generation) {
        socket.close();
        return;
      }
      _socket = socket;
      try {
        socket.joinMulticast(InternetAddress(_kMulticast));
      } catch (error) {
        logger.w('UDP multicast join error', error: error);
      }

      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        final message = utf8.decode(datagram.data, allowMalformed: true);
        final parsed = parseAnnouncement(message);
        if (parsed == null) return;

        _addHost(parsed.$1, name: AppStrings.appTitle, token: parsed.$2);
        final callback = _onFound;
        if (callback != null && !_onFoundCalled) {
          _onFoundCalled = true;
          callback(parsed.$1, parsed.$2);
        }
      });
    } catch (error) {
      _failure = error.toString();
      logger.e('UDP fallback discovery start error', error: error);
    }
  }

  void _addHost(
    String ip, {
    required String name,
    String? token,
    String? hostId,
    bool viaMdns = false,
  }) {
    if (InternetAddress.tryParse(ip)?.type != InternetAddressType.IPv4) return;
    final previous = _hosts[ip];
    final next = DiscoveredHost(
      ip: ip,
      name: name.isNotEmpty ? name : previous?.name ?? ip,
      pairingToken: token ?? previous?.pairingToken,
      viaMdns: viaMdns || previous?.viaMdns == true,
      hostId: hostId ?? previous?.hostId,
    );
    if (previous?.name == next.name &&
        previous?.pairingToken == next.pairingToken &&
        previous?.viaMdns == next.viaMdns &&
        previous?.hostId == next.hostId) {
      return;
    }
    _hosts[ip] = next;
    _onHostsChanged?.call(hosts);
  }

  void _finish(int generation) {
    if (!_active || generation != _generation) return;
    final elapsedMs = _scanStopwatch?.elapsedMilliseconds;
    _scanStopwatch?.stop();
    _scanStopwatch = null;
    _releaseDiscovery();
    _active = false;
    logger.i(
      '[Discovery] scan_finished elapsed_ms=${elapsedMs ?? 0} hosts=${_hosts.length}',
    );
    _onFinished?.call();
  }

  void stop() {
    if (!_active && _socket == null && _mdnsDiscovery == null) return;
    final elapsedMs = _scanStopwatch?.elapsedMilliseconds;
    _scanStopwatch?.stop();
    _scanStopwatch = null;
    if (_active) {
      logger.i(
        '[Discovery] scan_cancelled elapsed_ms=${elapsedMs ?? 0} hosts=${_hosts.length}',
      );
    }
    _active = false;
    _generation++;
    _releaseDiscovery();
  }

  void _releaseDiscovery() {
    _scanTimeout?.cancel();
    _udpFallbackDelay?.cancel();
    _scanTimeout = null;
    _udpFallbackDelay = null;
    _socket?.close();
    _socket = null;
    unawaited(_mdnsSubscription?.cancel());
    _mdnsSubscription = null;
    final discovery = _mdnsDiscovery;
    _mdnsDiscovery = null;
    if (discovery != null) {
      unawaited(
        discovery.stop().catchError((Object error) {
          logger.w('mDNS discovery stop failed', error: error);
        }),
      );
    }
  }
}
