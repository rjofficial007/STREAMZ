import 'dart:math';
import 'package:flutter/material.dart';

class GlitchEffect extends StatefulWidget {
  final Widget child;
  final bool active;

  const GlitchEffect({super.key, required this.child, this.active = false});

  @override
  State<GlitchEffect> createState() => _GlitchEffectState();
}

class _GlitchEffectState extends State<GlitchEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_random.nextDouble() > 0.3) return widget.child;

        return Stack(
          children: [
            widget.child,
            _buildGlitchLayer(Colors.white.withValues(alpha: 0.5), _random.nextDouble() * 10 - 5),
            _buildGlitchLayer(Colors.grey.withValues(alpha: 0.5), _random.nextDouble() * 10 - 5),
          ],
        );
      },
    );
  }

  Widget _buildGlitchLayer(Color color, double offset) {
    return Transform.translate(
      offset: Offset(offset, 0),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.modulate),
        child: widget.child,
      ),
    );
  }
}
