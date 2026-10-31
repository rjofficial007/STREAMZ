import 'package:flutter/widgets.dart';

enum AppFontFamily {
  manrope('Manrope'),
  inter('Inter'),
  roboto('Roboto'),
  lora('Lora');

  const AppFontFamily(this.label);
  final String label;
}

enum AppTitleWeight {
  light('Light', FontWeight.w300),
  normal('Normal', FontWeight.w400),
  medium('Medium', FontWeight.w500),
  semibold('Semibold', FontWeight.w600),
  bold('Bold', FontWeight.w700),
  extraBold('Extra bold', FontWeight.w800),
  black('Black', FontWeight.w900);

  const AppTitleWeight(this.label, this.weight);
  final String label;
  final FontWeight weight;
}

/// The app's type scale. Screens choose a role; responsive display sizes use
/// [style]. User text scaling remains controlled by Flutter's MediaQuery.
abstract final class AppTextStyles {
  static AppFontFamily fontFamily = AppFontFamily.manrope;
  static AppTitleWeight titleWeight = AppTitleWeight.medium;

  static FontWeight get titleFontWeight => titleWeight.weight;

  static TextStyle get caption => style(fontSize: 12);
  static TextStyle get supporting => style(fontSize: 13);
  static TextStyle get body => style(fontSize: 14);
  static TextStyle get bodyLarge => style(fontSize: 16);
  static TextStyle get title => style(fontSize: 18, fontWeight: titleFontWeight);
  static TextStyle get titleLarge =>
      style(fontSize: 20, fontWeight: titleFontWeight);
  static TextStyle get sectionTitle =>
      style(fontSize: 24, fontWeight: titleFontWeight);
  static TextStyle get headline =>
      style(fontSize: 28, fontWeight: titleFontWeight);

  static TextStyle style({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration = TextDecoration.none,
  }) {
    final size = (fontSize ?? 14).clamp(12.0, double.infinity).toDouble();
    final selectedWeight = fontWeight ?? FontWeight.w400;
    final weightAxis = switch (fontFamily) {
      AppFontFamily.manrope => selectedWeight.value.clamp(200, 800),
      AppFontFamily.inter => selectedWeight.value.clamp(100, 900),
      AppFontFamily.roboto => selectedWeight.value.clamp(100, 900),
      AppFontFamily.lora => selectedWeight.value.clamp(400, 700),
    };
    return TextStyle(
      fontFamily: fontFamily.label,
      fontSize: size,
      decoration: decoration,
      color: color,
      fontWeight: selectedWeight,
      fontVariations: [FontVariation('wght', weightAxis.toDouble())],
      letterSpacing: (letterSpacing ?? (size >= 24 ? -0.4 : 0))
          .clamp(-1.0, 0.8)
          .toDouble(),
      height: height ?? (size >= 28 ? 1.15 : (size >= 18 ? 1.3 : 1.4)),
    );
  }

  static TextStyle heading(double size, {double? spacing, Color? color}) =>
      style(
        fontSize: size,
        fontWeight: titleFontWeight,
        letterSpacing: spacing,
        color: color,
      );
  static TextStyle display(double size, {double? spacing, Color? color}) =>
      style(
        fontSize: size,
        fontWeight: FontWeight.w300,
        letterSpacing: spacing,
        color: color,
      );
  static TextStyle text(
    double size, {
    double? spacing,
    Color? color,
    FontWeight? weight,
  }) => style(
    fontSize: size,
    letterSpacing: spacing,
    color: color,
    fontWeight: weight,
  );

  static TextStyle get labelMd =>
      supporting.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get labelSm => caption.copyWith(fontWeight: FontWeight.w500);
  static TextStyle get titleMd => titleLarge;
}
