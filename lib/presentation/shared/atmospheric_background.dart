// presentation/shared/atmospheric_background.dart

import 'package:flutter/material.dart';

class AtmosphericBackground extends StatelessWidget {

  const AtmosphericBackground({super.key, this.colors, this.child});
  final List<Color>? colors;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final effectiveColors = colors;

    final themeColors = (effectiveColors == null || effectiveColors.isEmpty) 
        ? [Colors.black, Colors.black] 
        : effectiveColors.map((c) {
            final l = (c.computeLuminance() * 255).toInt();
            // FIX: Use c.a (float 0..1) instead of deprecated c.alpha (int 0..255)
            return Color.fromARGB((c.a * 255).toInt(), l, l, l);
          }).toList();

    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOutSine,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColors[0].withValues(alpha: 0.25),
                (themeColors.length > 1 ? themeColors[1] : themeColors[0]).withValues(alpha: 0.10),
                Colors.black,
              ],
              stops: const [0.0, 0.4, 0.9],
            ),
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [
                  (themeColors.length > 1 ? themeColors[1] : themeColors[0]).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        child ?? const SizedBox.shrink(),
      ],
    );
  }
}
