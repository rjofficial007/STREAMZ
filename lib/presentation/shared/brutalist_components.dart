// presentation/shared/brutalist_components.dart
// ============================================================================
// STREAMZ — Shared Brutalist & Technical UI Component Library
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streamz/core/theme/app_theme.dart';

class TechnicalProgressBar extends StatelessWidget {

  const TechnicalProgressBar({
    super.key,
    required this.progress,
    this.segments,
    this.color,
    this.height = 4.0,
    this.showLabel = false,
  });
  final double progress;
  final List<double>? segments; 
  final Color? color;
  final double height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeColor = color ?? tokens.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(color: tokens.surface3),
          child: Row(
            children: [
              Expanded(
                flex: (progress * 1000).toInt().clamp(1, 1000),
                child: Container(color: activeColor),
              ),
              Expanded(
                flex: ((1.0 - progress) * 1000).toInt().clamp(0, 1000),
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toInt()}% LOADED',
            style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}

class TechnicalCard extends StatefulWidget {

  const TechnicalCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.useStandardPadding = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool useStandardPadding;

  @override
  State<TechnicalCard> createState() => _TechnicalCardState();
}

class _TechnicalCardState extends State<TechnicalCard> {
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final active = _isFocused || _isPressed || widget.isSelected;

    return Focus(
      onFocusChange: (v) => setState(() => _isFocused = v),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: widget.useStandardPadding ? const EdgeInsets.all(16) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: active ? tokens.textPrimary : tokens.surface1,
            border: Border.all(
              color: active ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: DefaultTextStyle(
            style: TextStyle(color: active ? tokens.background : tokens.textPrimary),
            child: IconTheme(
              data: IconThemeData(color: active ? tokens.background : tokens.textPrimary, size: 20),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class TerminalBreadcrumbs extends StatelessWidget {

  const TerminalBreadcrumbs({super.key, required this.path, this.onBack});
  final List<String> path;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final displayPath = 'SYS:/${path.where((s) => s.isNotEmpty).join('/').toUpperCase()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          if (onBack != null && path.length > 1) ...[
            GestureDetector(
              onTap: onBack,
              child: Icon(LucideIcons.chevronLeft, size: 14, color: tokens.textSecondary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              displayPath,
              style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const _BlinkingCursor(),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _ctrl,
      child: Container(width: 6, height: 10, color: context.tokens.textMuted),
    );
}

class SignalWaveform extends StatefulWidget {
  const SignalWaveform({super.key, this.height = 40, this.color});
  final double height;
  final Color? color;

  @override
  State<SignalWaveform> createState() => _SignalWaveformState();
}

class _SignalWaveformState extends State<SignalWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _WavePainter(
          progress: _ctrl.value,
          color: widget.color ?? tokens.accent.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {

  _WavePainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (double i = 0; i <= size.width; i += 2) {
      final y = size.height / 2 + 
                math.sin((i / size.width * 4 * math.pi) + (progress * 2 * math.pi)) * (size.height / 3);
      if (i == 0) {
        path.moveTo(i, y);
      } else {
        path.lineTo(i, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}
