// domain/services/server_lifecycle_service.dart
// ============================================================================
// STREAMZ — Persistent Server Lifecycle Manager
// Keeps server alive across background, sleep, app switch, orientation change.
// Handles Android foreground service, WakeLock, network monitoring.
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:streamz/core/utils/logger.dart';
import 'package:streamz/domain/services/network_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Owned by GetIt as a singleton. Handles background execution,
/// WakeLock, and network monitoring for the server.
class ServerLifecycleService extends ChangeNotifier {
  ServerLifecycleService();

  bool _backgroundActive = false;
  bool _wakeLockHeld = false;
  Timer? _networkWatchdog;
  String _lastKnownIp = '';
  bool _initialized = false;

  /// Callback fired when network IP changes (server needs restart).
  void Function(String newIp)? onNetworkChange;

  /// Callback fired when background service drops (needs re-acquire).
  void Function()? onBackgroundLost;

  bool get isBackgroundActive => _backgroundActive;
  String get lastKnownIp => _lastKnownIp;

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Call once when server starts. Acquires all keep-alive mechanisms.
  Future<void> acquire({required String serverIp}) async {
    _lastKnownIp = serverIp;
    if (_initialized) {
      _startNetworkWatchdog();
      return;
    }
    _initialized = true;

    await _acquireWakeLock();
    await _acquireBackgroundService();
    _startNetworkWatchdog();
    notifyListeners();
  }

  /// Call when server manually stopped. Releases all keep-alive mechanisms.
  Future<void> release() async {
    _stopNetworkWatchdog();
    await _releaseWakeLock();
    await _releaseBackgroundService();
    _initialized = false;
    notifyListeners();
  }

  // ── WakeLock ───────────────────────────────────────────────────────────────

  Future<void> _acquireWakeLock() async {
    if (kIsWeb) return;
    try {
      await WakelockPlus.enable();
      _wakeLockHeld = true;
      logger.i('[Lifecycle] WakeLock acquired');
    } catch (e) {
      logger.e('[Lifecycle] WakeLock failed', error: e);
    }
  }

  Future<void> _releaseWakeLock() async {
    if (!_wakeLockHeld || kIsWeb) return;
    try {
      await WakelockPlus.disable();
      _wakeLockHeld = false;
      logger.i('[Lifecycle] WakeLock released');
    } catch (e) {
      logger.e('[Lifecycle] WakeLock release failed', error: e);
    }
  }

  // ── Android Background Service ─────────────────────────────────────────────

  Future<void> _acquireBackgroundService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        _backgroundActive = true;
        return;
      }

      const config = FlutterBackgroundAndroidConfig(
        notificationTitle: 'STREAMZ — Server Active',
        notificationText: 'Broadcasting on local network. Tap to open.',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        enableWifiLock: true,
      );

      final initialized = await FlutterBackground.initialize(androidConfig: config);
      if (!initialized) {
        logger.w('[Lifecycle] Background init failed');
        return;
      }

      final started = await FlutterBackground.enableBackgroundExecution();
      _backgroundActive = started;
      logger.i('[Lifecycle] Background service: $started');
    } catch (e) {
      logger.e('[Lifecycle] Background service error', error: e);
      _backgroundActive = false;
    }
  }

  Future<void> _releaseBackgroundService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_backgroundActive) return;

    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
      _backgroundActive = false;
      logger.i('[Lifecycle] Background service released');
    } catch (e) {
      logger.e('[Lifecycle] Background release error', error: e);
    }
  }

  // ── Network Watchdog ───────────────────────────────────────────────────────

  void _startNetworkWatchdog() {
    _stopNetworkWatchdog();
    _networkWatchdog = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _checkNetwork();
    });
  }

  void _stopNetworkWatchdog() {
    _networkWatchdog?.cancel();
    _networkWatchdog = null;
  }

  Future<void> _checkNetwork() async {
    if (kIsWeb) return;
    try {
      String? currentIp;

      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          // [FIX C10] Share NetworkService's LAN-IP predicate — this watchdog
          // used to only match 192.168.x/10.x, so an IP change onto a 172.x
          // network was never detected and the server kept the stale IP.
          if (NetworkService.isLanIp(addr.address)) {
            currentIp = addr.address;
            break;
          }
        }
        if (currentIp != null) break;
      }

      currentIp ??= await NetworkInfo().getWifiIP();

      if (currentIp != null && currentIp.isNotEmpty && currentIp != _lastKnownIp) {
        logger.i('[Lifecycle] IP changed: $_lastKnownIp → $currentIp');
        _lastKnownIp = currentIp;
        onNetworkChange?.call(currentIp);
        notifyListeners();
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && _initialized && !FlutterBackground.isBackgroundExecutionEnabled) {
        logger.w('[Lifecycle] Background dropped, re-acquiring...');
        await _acquireBackgroundService();
        onBackgroundLost?.call();
      }

      if (_initialized && !_wakeLockHeld) {
        await _acquireWakeLock();
      }
    } catch (e) {
      logger.e('[Lifecycle] Network check error', error: e);
    }
  }

  // ── App Lifecycle Bridge ───────────────────────────────────────────────────

  /// Call from WidgetsBindingObserver.didChangeAppLifecycleState
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (!_initialized) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Re-confirm WakeLock when going to background
        if (!_wakeLockHeld) _acquireWakeLock();
        break;
      case AppLifecycleState.resumed:
        // Validate everything still running after resume
        _checkNetwork();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Don't release — server must keep running
        break;
    }
  }

  @override
  void dispose() {
    // DO NOT call release() here — lifecycle service outlives any widget
    _stopNetworkWatchdog();
    super.dispose();
  }
}
