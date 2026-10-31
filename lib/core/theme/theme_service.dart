// core/theme/theme_service.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/core/theme/streamz_theme.dart';

enum AppGlowColor {
  blue('Blue', Color(0xFF0C3AA8)),
  violet('Amethyst', Color(0xFF402969)),
  teal('Aurora', Color(0xFF06443D)),
  rose('Rose', Color(0xFF5B2239)),
  amber('Champagne', Color(0xFF503A18)),
  ice('Arctic', Color(0xFF17405E));

  const AppGlowColor(this.label, this.color);
  final String label;
  final Color color;
}

enum AppCornerStyle {
  sharp('Sharp', 0),
  balanced('Balanced', 18),
  soft('Soft', 28);

  const AppCornerStyle(this.label, this.radius);
  final String label;
  final double radius;
}

class ThemeService extends ChangeNotifier {

  ThemeService(this._prefs) {
    _loadSettings();
  }
  static const String _themeKey = 'streamz_theme_identity';
  static const String _motionKey = 'streamz_reduced_motion';
  static const String _fontFamilyKey = 'streamz_font_family';
  static const String _glowColorKey = 'streamz_scaffold_glow_color';
  static const String _cornerStyleKey = 'streamz_corner_style';
  static const String _cornerRadiusKey = 'streamz_corner_radius';
  static const String _titleWeightKey = 'streamz_title_font_weight';
  final SharedPreferences _prefs;

  late StreamzTheme _currentTheme;
  late bool _reducedMotion;
  late AppFontFamily _fontFamily;
  late AppGlowColor _glowColor;
  late double _cornerRadius;
  late AppTitleWeight _titleWeight;

  StreamzTheme get currentTheme => _currentTheme;
  bool get reducedMotion => _reducedMotion;
  AppFontFamily get fontFamily => _fontFamily;
  AppGlowColor get glowColor => _glowColor;
  double get cornerRadius => _cornerRadius;
  AppTitleWeight get titleWeight => _titleWeight;

  void _loadSettings() {
    final identityIndex = _prefs.getInt(_themeKey) ?? ThemeIdentity.pureBlack.index;
    final identity = ThemeIdentity.values[
      identityIndex.clamp(0, ThemeIdentity.values.length - 1).toInt()
    ];
    _currentTheme = StreamzTheme.fromIdentity(identity);
    _reducedMotion = _prefs.getBool(_motionKey) ?? false;
    _fontFamily = _enumValue(
      AppFontFamily.values,
      _prefs.getInt(_fontFamilyKey),
      AppFontFamily.manrope,
    );
    _glowColor = _enumValue(
      AppGlowColor.values,
      _prefs.getInt(_glowColorKey),
      AppGlowColor.blue,
    );
    final legacyCornerStyle = _enumValue(
      AppCornerStyle.values,
      _prefs.getInt(_cornerStyleKey),
      AppCornerStyle.balanced,
    );
    _cornerRadius = (_prefs.getDouble(_cornerRadiusKey) ??
            legacyCornerStyle.radius)
        .clamp(0.0, 32.0)
        .toDouble();
    _titleWeight = _enumValue(
      AppTitleWeight.values,
      _prefs.getInt(_titleWeightKey),
      AppTitleWeight.medium,
    );
    AppTextStyles.fontFamily = _fontFamily;
    AppTextStyles.titleWeight = _titleWeight;
    DS.configureCornerRadius(_cornerRadius);
    notifyListeners();
  }

  T _enumValue<T extends Enum>(List<T> values, int? index, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
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

  Future<void> setFontFamily(AppFontFamily value) async {
    if (_fontFamily == value) return;
    _fontFamily = value;
    AppTextStyles.fontFamily = value;
    await _prefs.setInt(_fontFamilyKey, value.index);
    notifyListeners();
  }

  Future<void> setGlowColor(AppGlowColor value) async {
    if (_glowColor == value) return;
    _glowColor = value;
    await _prefs.setInt(_glowColorKey, value.index);
    notifyListeners();
  }

  void previewCornerRadius(double value) {
    final radius = value.clamp(0.0, 32.0).toDouble();
    if (_cornerRadius == radius) return;
    _cornerRadius = radius;
    DS.configureCornerRadius(radius);
    notifyListeners();
  }

  Future<void> persistCornerRadius() async {
    await _prefs.setDouble(_cornerRadiusKey, _cornerRadius);
  }

  void previewTitleWeight(AppTitleWeight value) {
    if (_titleWeight == value) return;
    _titleWeight = value;
    AppTextStyles.titleWeight = value;
    notifyListeners();
  }

  Future<void> persistTitleWeight() async {
    await _prefs.setInt(_titleWeightKey, _titleWeight.index);
  }

  Future<void> resetAppearance() async {
    _fontFamily = AppFontFamily.manrope;
    _glowColor = AppGlowColor.blue;
    _cornerRadius = AppCornerStyle.balanced.radius;
    _titleWeight = AppTitleWeight.medium;
    AppTextStyles.fontFamily = _fontFamily;
    AppTextStyles.titleWeight = _titleWeight;
    DS.configureCornerRadius(_cornerRadius);
    await Future.wait([
      _prefs.setInt(_fontFamilyKey, _fontFamily.index),
      _prefs.setInt(_glowColorKey, _glowColor.index),
      _prefs.setDouble(_cornerRadiusKey, _cornerRadius),
      _prefs.setInt(_titleWeightKey, _titleWeight.index),
    ]);
    notifyListeners();
  }

  // Helper to toggle between specific modes or cycle
  Future<void> cycleTheme() async {
    final nextIndex = (_currentTheme.identity.index + 1) % ThemeIdentity.values.length;
    await setTheme(ThemeIdentity.values[nextIndex]);
  }
}
