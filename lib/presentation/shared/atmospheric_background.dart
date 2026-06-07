// presentation/shared/atmospheric_background.dart

import 'package:flutter/material.dart';

class AtmosphericBackground extends StatelessWidget {
  final List<Color>? colors;
  final Widget? child;

  const AtmosphericBackground({super.key, this.colors, this.child});

  @override
  Widget build(BuildContext context) {
    // If no colors are provided, fall back to pure black (Brutalist default)
    final themeColors = (colors == null || colors!.isEmpty) 
        ? [Colors.black, Colors.black] 
        : colors!;

    return Stack(
      children: [
        // ── Atmosphere Layer ────────────────────────────────────────────────
        // Use an AnimatedContainer to smoothly transition between "vibes"
        // as media changes or different sessions are selected.
        AnimatedContainer(
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOutSine,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                // Primary vibe color at 25% opacity
                themeColors[0].withValues(alpha: 0.25),
                // Secondary vibe color (or primary again) at 10% opacity
                (themeColors.length > 1 ? themeColors[1] : themeColors[0]).withValues(alpha: 0.10),
                // Fade into the abyss
                Colors.black,
              ],
              stops: const [0.0, 0.4, 0.9],
            ),
          ),
        ),
        
        // ── Noise / Texture Layer (Optional - for high-end look) ──────────
        // This adds a subtle "glow" or "fog" feel
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

        // ── Content Layer ───────────────────────────────────────────────────
        if (child != null) child!,
      ],
    );
  }
}
