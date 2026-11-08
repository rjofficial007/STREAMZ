import 'package:flutter/material.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// Shared Hestia identity: the full icon for contained surfaces, or its
/// transparent mark for splash and brand lockups.
class AppBrandIcon extends StatelessWidget {
  const AppBrandIcon({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.transparent = false,
  });

  final double size;
  final double? borderRadius;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      transparent ? 'assets/images/app_mark.png' : 'assets/images/app_icon.png',
      width: transparent ? size * 1.45 : size,
      height: size,
      fit: transparent ? BoxFit.contain : BoxFit.cover,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );

    if (transparent) return image;

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        DS.radius(borderRadius ?? size * 0.2),
      ),
      child: image,
    );
  }
}
