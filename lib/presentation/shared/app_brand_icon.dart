import 'package:flutter/material.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// The shared STREAMZ mark used by app chrome and launch surfaces.
class AppBrandIcon extends StatelessWidget {
  const AppBrandIcon({
    super.key,
    this.size = 48,
    this.borderRadius,
  });

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(DS.radius(borderRadius ?? size * 0.2)),
    child: Image.asset(
      'assets/images/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    ),
  );
}
