// domain/services/device_id_service.dart
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {

  DeviceIdService(this._prefs);
  static const _key = 'client_device_id';
  final SharedPreferences _prefs;
  String? _cachedId;

  String get id {
    if (_cachedId != null) return _cachedId!;
    
    _cachedId = _prefs.getString(_key);
    if (_cachedId == null) {
      final rand = Random().nextInt(10000);
      final ts = DateTime.now().millisecondsSinceEpoch % 100000;
      _cachedId = 'NODE_${ts}_$rand';
      _prefs.setString(_key, _cachedId!);
    }
    return _cachedId!;
  }
}
