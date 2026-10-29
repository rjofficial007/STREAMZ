// core/theme/design_tokens.dart

import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';

/// DS — Design System Tokens
/// Single source of truth for spacing, color, and type.
abstract final class DS {
  // ── Breakpoints ──────────────────────────────────────────────────────────
  static const bpMobile = 600.0;
  static const bpTablet = 900.0;
  static const bpDesktop = 1200.0;
  static const bpTV = 1600.0;
  static const contentMaxWidth = 1280.0;

  // ── 8pt Spacing Grid ─────────────────────────────────────────────────────
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s48 = 48.0;
  static const s56 = 56.0;
  static const s64 = 64.0;
  static const s80 = 80.0;
  static const s96 = 96.0;

  // ── Color Palette ────────────────────────────────────────────────────────
  // Backgrounds (elevation-aware grayscale)
  static const bg = Color(0xFF000000);
  static const scaffoldBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
    colors: [Color(0xFF0A0A0C), Color(0xFF060606), Color(0xFF020202)],
  );
  static const scaffoldGlow = RadialGradient(
    center: Alignment(0, -1.15),
    radius: 0.9,
    stops: [0.0, 0.35, 1.0],
    colors: [Color(0xD90C3AA8), Color(0x400C3AA8), Colors.transparent],
  );
  static const scaffoldGlowColor = Color(0xFF0C3AA8);
  static const surface1 = Color(0xFF0A0D14); // Default card bg
  static const surface2 = Color(0xFF0E121B); // Raised / modal
  static const surface3 = Color(0xFF171D29); // Hover / focus bg
  static const surface4 = Color(0xFF222B3A); // Selected state

  // Accent / Brand (Pure White)
  static const accent = Color(0xFFF3F4F6);
  static const accentDim = Color(0x80FFFFFF);
  static const accentFaint = Color(0x20FFFFFF);

  // Status colors (Mapped to Grayscale for Strict Aesthetic)
  static const danger = Color(0xFFFFFFFF); // High contrast white
  static const success = Color(0xFFFFFFFF); // High contrast white
  static const warning = Color(0xFFB0B0B0); // Mid-gray
  static const info = Color(0xFF808080); // Darker gray

  // Text hierarchy
  static const textPrimary = Color(0xFFF1F2F5);
  static const textSecondary = Color(0xFFB7BCC6);
  static const textMuted = Color(0xFF989EAA);
  static const textDisabled = Color(0xFF454A54);

  // Borders
  static const borderSubtle = Color(0xFF171D29);
  static const borderDefault = Color(0xFF293142);
  static const borderStrong = Color(0xFF3B465A);

  // Shared geometry for screens and controls.
  static const _radiusBase = 18.0;
  static double _cornerRadius = _radiusBase;

  static double radius(double baseRadius) =>
      (baseRadius * (_cornerRadius / _radiusBase)).clamp(0.0, 32.0).toDouble();

  static double get radiusSm => radius(12);
  static double get radiusMd => radius(_radiusBase);
  static double get radiusLg => radius(24);

  static void configureCornerRadius(double value) {
    _cornerRadius = value.clamp(0, 32).toDouble();
  }

  // Focus ring (TV-critical)
  static const focusColor = Color(0xFFF3F4F6);
  static const focusWidth = 3.0;
  static const focusShadowColor = Color(0x80FFFFFF);

  // ── Rail / Card Sizing ───────────────────────────────────────────────────
  static const railCardW = 200.0; // 16:9 → h=112.5
  static const railCardH = 112.5;
  static const railCardWTV = 280.0; // TV
  static const railCardHTV = 157.5;
  static const railCardWSq = 140.0; // Square (audio)
  static const railCardWTVSq = 180.0;

  // Legacy square radius token for progress and media frames that need flush edges.
  static const radius0 = 0.0;

  // ── Typography ───────────────────────────────────────────────────────────
  static TextStyle displayHero(double screenW) => AppTextStyles.style(
    fontSize: (screenW * 0.07).clamp(40.0, 120.0),
    fontWeight: FontWeight.w300,
    letterSpacing: -0.8,
    height: 0.9,
    color: textPrimary,
  );

  static TextStyle get displayLg => AppTextStyles.style(
    fontSize: 72,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.8,
    height: 0.95,
    color: textPrimary,
  );

  static TextStyle get displayMd => AppTextStyles.style(
    fontSize: 48,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    height: 1.0,
    color: textPrimary,
  );

  static TextStyle get titleLg => AppTextStyles.style(
    fontSize: 28,
    fontWeight: AppTextStyles.titleFontWeight,
    letterSpacing: 0.5,
    color: textPrimary,
  );

  static TextStyle get titleMd => AppTextStyles.style(
    fontSize: 20,
    fontWeight: AppTextStyles.titleFontWeight,
    letterSpacing: 0.5,
    color: textPrimary,
  );

  static TextStyle get labelLg => AppTextStyles.style(
    fontSize: 13,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static TextStyle get labelMd => AppTextStyles.style(
    fontSize: 11,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static TextStyle get labelSm => AppTextStyles.style(
    fontSize: 9,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  static TextStyle get bodyLg => AppTextStyles.style(
    fontSize: 16,
    fontWeight: FontWeight.w300,
    height: 1.6,
    color: textSecondary,
  );

  static TextStyle get bodySm => AppTextStyles.style(
    fontSize: 13,
    fontWeight: FontWeight.w300,
    height: 1.5,
    color: textSecondary,
  );

  // ── Helpers ───────────────────────────────────────────────────────────────
  static double hPad(double width) {
    if (width >= bpTV) return s80;
    if (width >= bpDesktop) return s48;
    if (width >= bpTablet) return s32;
    return s16;
  }

  static bool isMobile(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width < bpMobile;
  static bool isTablet(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width < bpTablet;
  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width >= bpTablet;
  static bool isTV(BuildContext ctx) =>
      TVDeviceScope.of(ctx) || MediaQuery.sizeOf(ctx).width >= bpTV;

  // Fluid font helper — clamps between min and max based on screen width
  static double fluid(
    BuildContext ctx, {
    required double min,
    required double max,
    double factor = 0.025,
  }) => (MediaQuery.sizeOf(ctx).width * factor).clamp(min, max);

  /// Selects a readable grid column count using available width and text scale.
  static int responsiveColumns(
    BuildContext context, {
    required double availableWidth,
    required double spacing,
    required double minTileWidth,
    required int maxColumns,
  }) {
    assert(spacing >= 0, 'spacing must be non-negative.');
    assert(minTileWidth > 0, 'minTileWidth must be positive.');
    assert(maxColumns > 0, 'maxColumns must be positive.');
    final textScale =
        MediaQuery.textScalerOf(context).scale(14).clamp(14.0, 28.0) / 14;
    return ((availableWidth + spacing) / (minTileWidth * textScale + spacing))
        .floor()
        .clamp(1, maxColumns)
        .toInt();
  }
}

/// Carries device-level TV detection into responsive widgets. Screen width
/// remains a fallback for large desktop and web windows.
class TVDeviceScope extends InheritedWidget {
  const TVDeviceScope({
    super.key,
    required this.isTelevision,
    required super.child,
  });

  final bool isTelevision;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TVDeviceScope>()
          ?.isTelevision ??
      false;

  @override
  bool updateShouldNotify(TVDeviceScope oldWidget) =>
      isTelevision != oldWidget.isTelevision;
}
