// presentation/shared/noc_decorations.dart
// Shared decorative components for the STREAMZ NOC aesthetic.

import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class NocGridBackground extends StatelessWidget {
  final double spacing;
  final Color? color;
  final Widget? child;

  const NocGridBackground({
    super.key,
    this.spacing = 60,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GridPainter(
        spacing: spacing,
        color: color ?? DS.borderSubtle,
      ),
      child: child,
    );
  }
}

class GridPainter extends CustomPainter {
  const GridPainter({this.spacing = 40, this.color = DS.borderDefault});
  final double spacing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) => old.spacing != spacing || old.color != color;
}

class NocScanningLine extends StatefulWidget {
  final Color? color;
  final Duration duration;
  final bool reducedMotion;

  const NocScanningLine({
    super.key,
    this.color,
    this.duration = const Duration(seconds: 4),
    this.reducedMotion = false,
  });

  @override
  State<NocScanningLine> createState() => _NocScanningLineState();
}

class _NocScanningLineState extends State<NocScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (!widget.reducedMotion) _controller.repeat();
    
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }

  @override
  void didUpdateWidget(covariant NocScanningLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion != oldWidget.reducedMotion) {
      if (widget.reducedMotion) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DS.accent.withValues(alpha: 0.1);
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: MediaQuery.sizeOf(context).height * _animation.value,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: color,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0),
                      color,
                      color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class NocTelemetryViz extends StatefulWidget {
  final Color? color;
  final bool isActive;

  const NocTelemetryViz({
    super.key,
    this.color,
    this.isActive = true,
  });

  @override
  State<NocTelemetryViz> createState() => _NocTelemetryVizState();
}

class _NocTelemetryVizState extends State<NocTelemetryViz> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _points = List.generate(20, (_) => 0.5);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..repeat();
    _controller.addListener(() {
      if (widget.isActive) {
        setState(() {
          _points.removeAt(0);
          _points.add(0.2 + (0.6 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000));
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DS.info;
    return CustomPaint(
      painter: TelemetryPainter(points: _points, color: color),
      size: const Size(double.infinity, 40),
    );
  }
}

class TelemetryPainter extends CustomPainter {
  final List<double> points;
  final Color color;

  TelemetryPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TelemetryPainter old) => true;
}

class NocCornerBracket extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final double thickness;
  final Color? color;

  const NocCornerBracket({
    super.key,
    required this.alignment,
    this.size = 12,
    this.thickness = 1.5,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = color ?? DS.textPrimary;
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight 
                ? BorderSide(color: borderColor, width: thickness) : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight 
                ? BorderSide(color: borderColor, width: thickness) : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft 
                ? BorderSide(color: borderColor, width: thickness) : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight 
                ? BorderSide(color: borderColor, width: thickness) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
