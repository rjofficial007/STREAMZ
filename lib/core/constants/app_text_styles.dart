// core/constants/app_text_styles.dart

import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:streamz/core/theme/design_tokens.dart';

abstract final class AppTextStyles {
  static TextStyle barlowBold(double size, {double? spacing, Color? color}) => GoogleFonts.barlowCondensed(
    fontSize: size,
    fontWeight: FontWeight.bold,
    letterSpacing: spacing,
    color: color,
  );

  static TextStyle barlowBlack(double size, {double? spacing, Color? color}) => GoogleFonts.barlowCondensed(
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: spacing,
    color: color,
  );

  static TextStyle mono(double size, {double? spacing, Color? color, FontWeight? weight}) => GoogleFonts.dmMono(
    fontSize: size,
    letterSpacing: spacing,
    color: color,
    fontWeight: weight,
  );

  // Specific common styles
  static final labelMd = DS.labelMd;
  static final labelSm = DS.labelSm;
  static final titleMd = DS.titleMd;
}
