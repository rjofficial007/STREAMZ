// core/theme/streamz_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/core/theme/theme_tokens.dart';

enum ThemeIdentity { pureBlack }

class StreamzTheme {

  const StreamzTheme({
    required this.identity,
    required this.name,
    required this.tokens,
  });
  final ThemeIdentity identity;
  final String name;
  final StreamzThemeExtension tokens;

  static StreamzTheme get pureBlack => const StreamzTheme(
    identity: ThemeIdentity.pureBlack,
    name: 'Pure Black',
    tokens: StreamzThemeExtension(
      background: DS.bg,
      surface1: DS.surface1,
      surface2: DS.surface2,
      surface3: DS.surface3,
      surface4: DS.surface4,
      primary: DS.accent,
      accent: DS.accent,
      border: DS.borderDefault,
      borderSubtle: DS.borderSubtle,
      borderStrong: DS.borderStrong,
      success: DS.success,
      warning: DS.warning,
      error: DS.danger,
      telemetry: DS.info,
      broadcast: DS.warning,
      textPrimary: DS.textPrimary,
      textSecondary: DS.textSecondary,
      textMuted: DS.textMuted,
      textDisabled: DS.textDisabled,
      focusColor: DS.focusColor,
      focusShadow: DS.focusShadowColor,
    ),
  );

  static List<StreamzTheme> get all => [pureBlack];

  static StreamzTheme fromIdentity(ThemeIdentity identity) => pureBlack;

  // Compatibility with main.dart and legacy code
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  
  // Even "light" requests return the black aesthetic for strict B&W enforcement
  static ThemeData get lightTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final themeBase = pureBlack;
    
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: themeBase.tokens.primary,
      scaffoldBackgroundColor: themeBase.tokens.background,
      canvasColor: themeBase.tokens.surface1,
      appBarTheme: AppBarTheme(
        backgroundColor: themeBase.tokens.background,
        foregroundColor: themeBase.tokens.textPrimary,
        elevation: 0,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.barlowCondensed(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: themeBase.tokens.textPrimary,
        ),
        labelLarge: GoogleFonts.dmMono(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: themeBase.tokens.textPrimary,
        ),
      ),
    );
  }
}
