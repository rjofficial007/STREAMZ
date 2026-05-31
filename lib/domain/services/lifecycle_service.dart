import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/utils/logger.dart';

class LifecycleService extends ChangeNotifier {
  bool _wakeLockHeld = false;
  bool _backgroundActive = false;

  bool get wakeLockHeld => _wakeLockHeld;
  bool get backgroundActive => _backgroundActive;

  Future<void> acquireKeepAlive() async {
    await _acquireWakeLock();
    await _acquireBackgroundService();
  }

  Future<void> releaseKeepAlive() async {
    await _releaseWakeLock();
    await _releaseBackgroundService();
  }

  Future<void> _acquireWakeLock() async {
    if (kIsWeb || _wakeLockHeld) return;
    try {
      await WakelockPlus.enable();
      _wakeLockHeld = true;
      logger.i('WakeLock acquired');
    } catch (e) {
      logger.e('WakeLock error', error: e);
    }
  }

  Future<void> _releaseWakeLock() async {
    if (!_wakeLockHeld) return;
    try {
      await WakelockPlus.disable();
      _wakeLockHeld = false;
      logger.i('WakeLock released');
    } catch (e) {
      logger.e('WakeLock release error', error: e);
    }
  }

  Future<void> _acquireBackgroundService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_backgroundActive) return;
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
      final ok = await FlutterBackground.initialize(androidConfig: config);
      if (ok) {
        await FlutterBackground.enableBackgroundExecution();
        _backgroundActive = true;
        logger.i('Background service acquired');
      }
    } catch (e) {
      logger.e('Background service error', error: e);
    }
  }

  Future<void> _releaseBackgroundService() async {
    if (!_backgroundActive || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
      _backgroundActive = false;
      logger.i('Background service released');
    } catch (e) {
      logger.e('Background release error', error: e);
    }
  }
}
