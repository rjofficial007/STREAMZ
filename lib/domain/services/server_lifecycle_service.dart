// domain/services/server_lifecycle_service.dart
// ============================================================================
// STREAMZ — Persistent Server Lifecycle Manager
// Keeps server alive across background, sleep, app switch, orientation change.
// Handles Android foreground service, WakeLock, network monitoring.
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/utils/logger.dart';
import 'package:streamz/domain/services/network_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Owned by GetIt as a singleton. Handles background execution,
/// WakeLock, and network monitoring for the server.
class ServerLifecycleService extends ChangeNotifier {
  ServerLifecycleService({NetworkService? networkService})
    : _networkService = networkService ?? NetworkService();

  final NetworkService _networkService;

  bool _backgroundActive = false;
  bool _wakeLockHeld = false;
  Stopwatch? _wakeLockStopwatch;
  Timer? _networkWatchdog;
  StreamSubscription<Object?>? _connectivitySubscription;
  bool _networkCheckRunning = false;
  String _lastKnownIp = '';
  String _lastKnownInterfaceName = '';
  bool _initialized = false;

  /// Callback fired when network IP changes (server needs restart).
  void Function(String? newIp)? onNetworkChange;

  /// Callback fired when background service drops (needs re-acquire).
  void Function()? onBackgroundLost;

  bool get isBackgroundActive => _backgroundActive;
  String get lastKnownIp => _lastKnownIp;

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Call once when server starts. Acquires all keep-alive mechanisms.
  Future<void> acquire({required String serverIp}) async {
    _lastKnownIp = serverIp;
    _lastKnownInterfaceName = _networkService.currentInterfaceName;
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
      _wakeLockStopwatch = Stopwatch()..start();
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
      final heldFor = _wakeLockStopwatch?.elapsed ?? Duration.zero;
      _wakeLockStopwatch?.stop();
      _wakeLockStopwatch = null;
      logger.i(
        '[Lifecycle] WakeLock released held_ms=${heldFor.inMilliseconds}',
      );
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
        notificationTitle: '${AppStrings.appTitle} — Server Active',
        notificationText: 'Broadcasting on local network. Tap to open.',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
        enableWifiLock: true,
      );

      final initialized = await FlutterBackground.initialize(
        androidConfig: config,
      );
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _connectivitySubscription = _networkService.networkChanges.listen(
        (_) => unawaited(_checkNetwork()),
      );
      unawaited(_checkNetwork());
    }
    // Native callbacks are not available on every desktop platform; this
    // bounded fallback also catches missed address changes and resumes.
    _networkWatchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_checkNetwork());
    });
  }

  void _stopNetworkWatchdog() {
    _networkWatchdog?.cancel();
    _networkWatchdog = null;
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
  }

  Future<void> _checkNetwork() async {
    if (kIsWeb || _networkCheckRunning) return;
    _networkCheckRunning = true;
    try {
      final detectedIp = await _networkService.detectIp();
      final currentIp = detectedIp == 'No Network' || detectedIp == '127.0.0.1'
          ? null
          : detectedIp;
      final normalizedIp = currentIp ?? '';
      final interfaceName = _networkService.currentInterfaceName;

      if (normalizedIp != _lastKnownIp ||
          interfaceName != _lastKnownInterfaceName) {
        logger.i(
          '[Lifecycle] Route changed: $_lastKnownIp/$_lastKnownInterfaceName'
          ' → ${currentIp ?? 'offline'}/$interfaceName',
        );
        _lastKnownIp = normalizedIp;
        _lastKnownInterfaceName = interfaceName;
        onNetworkChange?.call(currentIp);
        notifyListeners();
      }

      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          _initialized &&
          !FlutterBackground.isBackgroundExecutionEnabled) {
        logger.w('[Lifecycle] Background dropped, re-acquiring...');
        await _acquireBackgroundService();
        onBackgroundLost?.call();
      }

      if (_initialized && !_wakeLockHeld) {
        await _acquireWakeLock();
      }
    } catch (e) {
      logger.e('[Lifecycle] Network check error', error: e);
    } finally {
      _networkCheckRunning = false;
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
