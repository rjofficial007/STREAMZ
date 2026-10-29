// core/theme/theme_tokens.dart

import 'package:flutter/material.dart';

/// StreamzThemeExtension — Custom Design Tokens for the STREAMZ Visual System.
class StreamzThemeExtension extends ThemeExtension<StreamzThemeExtension> {
  const StreamzThemeExtension({
    required this.background,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.surface4,
    required this.primary,
    required this.accent,
    required this.border,
    required this.borderSubtle,
    required this.borderStrong,
    required this.success,
    required this.warning,
    required this.error,
    required this.telemetry,
    required this.broadcast,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.focusColor,
    required this.focusShadow,
    this.scaffoldTopColor = const Color(0xFF0C3AA8),
    this.borderRadius = 18.0,
    this.useGradient = false,
  });
  final Color background;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color surface4;
  final Color primary;
  final Color accent;
  final Color border;
  final Color borderSubtle;
  final Color borderStrong;
  final Color success;
  final Color warning;
  final Color error;
  final Color telemetry;
  final Color broadcast;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color focusColor;
  final Color focusShadow;
  final Color scaffoldTopColor;

  // Structural & Texture Tokens for "Total Transformation"
  final double borderRadius;
  final bool useGradient;

  @override
  StreamzThemeExtension copyWith({
    Color? background,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? surface4,
    Color? primary,
    Color? accent,
    Color? border,
    Color? borderSubtle,
    Color? borderStrong,
    Color? success,
    Color? warning,
    Color? error,
    Color? telemetry,
    Color? broadcast,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? focusColor,
    Color? focusShadow,
    Color? scaffoldTopColor,
    double? borderRadius,
    bool? useGradient,
  }) => StreamzThemeExtension(
    background: background ?? this.background,
    surface1: surface1 ?? this.surface1,
    surface2: surface2 ?? this.surface2,
    surface3: surface3 ?? this.surface3,
    surface4: surface4 ?? this.surface4,
    primary: primary ?? this.primary,
    accent: accent ?? this.accent,
    border: border ?? this.border,
    borderSubtle: borderSubtle ?? this.borderSubtle,
    borderStrong: borderStrong ?? this.borderStrong,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    telemetry: telemetry ?? this.telemetry,
    broadcast: broadcast ?? this.broadcast,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    textDisabled: textDisabled ?? this.textDisabled,
    focusColor: focusColor ?? this.focusColor,
    focusShadow: focusShadow ?? this.focusShadow,
    scaffoldTopColor: scaffoldTopColor ?? this.scaffoldTopColor,
    borderRadius: borderRadius ?? this.borderRadius,
    useGradient: useGradient ?? this.useGradient,
  );

  @override
  ThemeExtension<StreamzThemeExtension> lerp(
    ThemeExtension<StreamzThemeExtension>? other,
    double t,
  ) {
    if (other is! StreamzThemeExtension) return this;
    return StreamzThemeExtension(
      background: Color.lerp(background, other.background, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      surface4: Color.lerp(surface4, other.surface4, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      telemetry: Color.lerp(telemetry, other.telemetry, t)!,
      broadcast: Color.lerp(broadcast, other.broadcast, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      focusColor: Color.lerp(focusColor, other.focusColor, t)!,
      focusShadow: Color.lerp(focusShadow, other.focusShadow, t)!,
      scaffoldTopColor: Color.lerp(
        scaffoldTopColor,
        other.scaffoldTopColor,
        t,
      )!,
      borderRadius: borderRadius + (other.borderRadius - borderRadius) * t,
      useGradient: t < 0.5 ? useGradient : other.useGradient,
    );
  }
}
