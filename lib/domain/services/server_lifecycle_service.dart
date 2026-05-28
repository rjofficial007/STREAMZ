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
import 'package:wakelock_plus/wakelock_plus.dart';

/// Singleton that owns the server's always-on lifecycle.
/// ServerViewModel delegates start/stop here instead of directly managing HTTP.
class ServerLifecycleService extends ChangeNotifier {
  static final ServerLifecycleService _instance = ServerLifecycleService._();
  factory ServerLifecycleService() => _instance;
  ServerLifecycleService._();

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
      debugPrint('[Lifecycle] WakeLock acquired');
    } catch (e) {
      debugPrint('[Lifecycle] WakeLock failed: $e');
    }
  }

  Future<void> _releaseWakeLock() async {
    if (!_wakeLockHeld || kIsWeb) return;
    try {
      await WakelockPlus.disable();
      _wakeLockHeld = false;
      debugPrint('[Lifecycle] WakeLock released');
    } catch (e) {
      debugPrint('[Lifecycle] WakeLock release failed: $e');
    }
  }

  // ── Android Background Service ─────────────────────────────────────────────

  Future<void> _acquireBackgroundService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      // Check if already initialized and enabled
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        _backgroundActive = true;
        return;
      }

      // Initialize config
      const config = FlutterBackgroundAndroidConfig(
        notificationTitle: 'STREAMZ — Server Active',
        notificationText: 'Broadcasting on local network. Tap to open.',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        enableWifiLock: true, // Critical: prevents WiFi from sleeping
      );

      final initialized = await FlutterBackground.initialize(androidConfig: config);
      if (!initialized) {
        debugPrint('[Lifecycle] Background init failed');
        return;
      }

      final started = await FlutterBackground.enableBackgroundExecution();
      _backgroundActive = started;
      debugPrint('[Lifecycle] Background service: $started');
    } catch (e) {
      debugPrint('[Lifecycle] Background service error: $e');
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
      debugPrint('[Lifecycle] Background service released');
    } catch (e) {
      debugPrint('[Lifecycle] Background release error: $e');
    }
  }

  // ── Network Watchdog ───────────────────────────────────────────────────────

  void _startNetworkWatchdog() {
    _stopNetworkWatchdog();
    // Check network every 15 seconds
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

      // Try NetworkInterface first (most reliable)
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.')) {
            currentIp = addr.address;
            break;
          }
        }
        if (currentIp != null) break;
      }

      // Fallback to NetworkInfo
      currentIp ??= await NetworkInfo().getWifiIP();

      if (currentIp != null && currentIp.isNotEmpty && currentIp != _lastKnownIp) {
        debugPrint('[Lifecycle] IP changed: $_lastKnownIp → $currentIp');
        _lastKnownIp = currentIp;
        onNetworkChange?.call(currentIp);
        notifyListeners();
      }

      // Re-acquire background service if it dropped
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && _initialized && !FlutterBackground.isBackgroundExecutionEnabled) {
        debugPrint('[Lifecycle] Background dropped, re-acquiring...');
        await _acquireBackgroundService();
        onBackgroundLost?.call();
      }

      // Re-acquire WakeLock if dropped
      if (_initialized && !_wakeLockHeld) {
        await _acquireWakeLock();
      }
    } catch (e) {
      debugPrint('[Lifecycle] Network check error: $e');
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
