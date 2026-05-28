// core/theme/design_tokens.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DS — Design System Tokens
/// Single source of truth for spacing, color, and type.
abstract final class DS {
  // ── Breakpoints ──────────────────────────────────────────────────────────
  static const bpMobile = 600.0;
  static const bpTablet = 900.0;
  static const bpDesktop = 1200.0;
  static const bpTV = 1600.0;

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

  // ── Color Palette ─────────────────────────────────────────────────────────
  // Backgrounds (elevation-aware)
  static const bg = Color(0xFF000000);
  static const surface1 = Color(0xFF0A0A0A); // Default card bg
  static const surface2 = Color(0xFF111111); // Raised / modal
  static const surface3 = Color(0xFF181818); // Hover / focus bg
  static const surface4 = Color(0xFF222222); // Selected state

  // Accent / Brand
  static const accent = Color(0xFFFFFFFF);
  static const accentDim = Color(0x80FFFFFF);
  static const accentFaint = Color(0x20FFFFFF);

  // Status colors
  static const danger = Color(0xFFFF3B30);
  static const success = Color(0xFF30D158);
  static const warning = Color(0xFFFFD60A);
  static const info = Color(0xFF0A84FF);

  // Text hierarchy
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x80FFFFFF);
  static const textMuted = Color(0x4DFFFFFF);
  static const textDisabled = Color(0x26FFFFFF);

  // Borders
  static const borderSubtle = Color(0x14FFFFFF);
  static const borderDefault = Color(0x20FFFFFF);
  static const borderStrong = Color(0x60FFFFFF);

  // Focus ring (TV-critical)
  static const focusColor = Color(0xFFFFFFFF);
  static const focusWidth = 3.0;
  static const focusShadowColor = Color(0x80FFFFFF); // Increased from 0x40 for better TV visibility

  // ── Rail / Card Sizing ───────────────────────────────────────────────────
  static const railCardW = 200.0; // 16:9 → h=112.5
  static const railCardH = 112.5;
  static const railCardWTV = 280.0; // TV
  static const railCardHTV = 157.5;
  static const railCardWSq = 140.0; // Square (audio)
  static const railCardWTVSq = 180.0;

  // ── Radius ───────────────────────────────────────────────────────────────
  // Brutalist → zero radius everywhere, intentional
  static const radius0 = 0.0;

  // ── Typography ───────────────────────────────────────────────────────────
  static TextStyle displayHero(double screenW) =>
      GoogleFonts.barlowCondensed(fontSize: (screenW * 0.07).clamp(40.0, 120.0), fontWeight: FontWeight.w900, letterSpacing: -2.0, height: 0.9, color: textPrimary);

  static TextStyle displayLg = GoogleFonts.barlowCondensed(fontSize: 72, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 0.95, color: textPrimary);

  static TextStyle displayMd = GoogleFonts.barlowCondensed(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1.0, height: 1.0, color: textPrimary);

  static TextStyle titleLg = GoogleFonts.barlowCondensed(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: textPrimary);

  static TextStyle titleMd = GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: textPrimary);

  static TextStyle labelLg = GoogleFonts.dmMono(fontSize: 13, letterSpacing: 2.0, fontWeight: FontWeight.w500, color: textPrimary);

  static TextStyle labelMd = GoogleFonts.dmMono(fontSize: 11, letterSpacing: 2.0, fontWeight: FontWeight.w500, color: textPrimary);

  static TextStyle labelSm = GoogleFonts.dmMono(fontSize: 9, letterSpacing: 2.5, fontWeight: FontWeight.w500, color: textMuted);

  static TextStyle bodyLg = GoogleFonts.barlow(fontSize: 16, fontWeight: FontWeight.w300, height: 1.6, color: textSecondary);

  static TextStyle bodySm = GoogleFonts.barlow(fontSize: 13, fontWeight: FontWeight.w300, height: 1.5, color: textSecondary);

  // ── Helpers ───────────────────────────────────────────────────────────────
  static double hPad(double width) {
    if (width >= bpTV) return s80;
    if (width >= bpDesktop) return s48;
    if (width >= bpTablet) return s32;
    return s16;
  }

  static bool isMobile(BuildContext ctx) => MediaQuery.sizeOf(ctx).width < bpMobile;
  static bool isTablet(BuildContext ctx) => MediaQuery.sizeOf(ctx).width < bpTablet;
  static bool isDesktop(BuildContext ctx) => MediaQuery.sizeOf(ctx).width >= bpTablet;
  static bool isTV(BuildContext ctx) => MediaQuery.sizeOf(ctx).width >= bpTV;

  // Fluid font helper — clamps between min and max based on screen width
  static double fluid(BuildContext ctx, {required double min, required double max, double factor = 0.025}) => (MediaQuery.sizeOf(ctx).width * factor).clamp(min, max);
}
