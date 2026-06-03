// core/theme/theme_service.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'streamz_theme.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'streamz_theme_identity';
  static const String _motionKey = 'streamz_reduced_motion';
  final SharedPreferences _prefs;

  late StreamzTheme _currentTheme;
  late bool _reducedMotion;

  ThemeService(this._prefs) {
    _loadSettings();
  }

  StreamzTheme get currentTheme => _currentTheme;
  bool get reducedMotion => _reducedMotion;

  void _loadSettings() {
    final identityIndex = _prefs.getInt(_themeKey) ?? ThemeIdentity.pureBlack.index;
    final identity = ThemeIdentity.values[identityIndex.clamp(0, ThemeIdentity.values.length - 1)];
    _currentTheme = StreamzTheme.fromIdentity(identity);
    _reducedMotion = _prefs.getBool(_motionKey) ?? false;
    notifyListeners();
  }

  Future<void> setTheme(ThemeIdentity identity) async {
    if (_currentTheme.identity == identity) return;

    _currentTheme = StreamzTheme.fromIdentity(identity);
    await _prefs.setInt(_themeKey, identity.index);
    notifyListeners();
  }

  Future<void> setReducedMotion(bool value) async {
    if (_reducedMotion == value) return;
    _reducedMotion = value;
    await _prefs.setBool(_motionKey, value);
    notifyListeners();
  }

  // Helper to toggle between specific modes or cycle
  Future<void> cycleTheme() async {
    final nextIndex = (_currentTheme.identity.index + 1) % ThemeIdentity.values.length;
    await setTheme(ThemeIdentity.values[nextIndex]);
  }
}
