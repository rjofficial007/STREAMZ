// presentation/client/qr_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _isFlashOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final scanWindowSize = (size.width * 0.75).clamp(0.0, size.height * 0.56);

    return AppScaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  context.pop(barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // Overlay with cutout
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: tokens.accent,
                borderWidth: 2.0,
                overlayColor: tokens.background.withValues(alpha: 0.88),
                cutOutSize: scanWindowSize,
              ),
            ),
          ),
          // Controls
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(DS.s16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppBackButton(
                        onPressed: () => context.pop(),
                        color: tokens.textPrimary,
                        iconSize: 24,
                      ),
                      Actions(
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (_) {
                              _controller.toggleTorch();
                              setState(() => _isFlashOn = !_isFlashOn);
                              return null;
                            },
                          ),
                        },
                        child: Focus(
                          onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
                            _controller.toggleTorch();
                            setState(() => _isFlashOn = !_isFlashOn);
                          }),
                          child: IconButton(
                            icon: Icon(
                              _isFlashOn ? LucideIcons.zap : LucideIcons.zapOff,
                              color: _isFlashOn
                                  ? tokens.accent
                                  : tokens.textPrimary,
                              size: 24,
                            ),
                            onPressed: () {
                              _controller.toggleTorch();
                              setState(() => _isFlashOn = !_isFlashOn);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s24,
                    vertical: DS.s20,
                  ),
                  margin: const EdgeInsets.only(
                    bottom: 40,
                    left: DS.s16,
                    right: DS.s16,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surface1.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(DS.radius(20)),
                    border: Border.all(
                      color: tokens.border.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Scan QR code',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: DS.s8),
                      Text(
                        'Align the code within the frame',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayShape extends ShapeBorder {
  const _ScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 1.0,
    this.overlayColor = const Color(0x88000000),
    this.cutOutSize = 250.0,
  });
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..fillType = PathFillType.evenOdd
    ..addPath(getOuterPath(rect), Offset.zero);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path base(Rect r) => Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top)
      ..lineTo(r.right, r.top);

    return base(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..moveTo(rect.left + rect.width / 2, rect.top + rect.height / 2)
      ..addRect(
        Rect.fromCenter(
          center: Offset(rect.width / 2, rect.height / 2),
          width: cutOutSize,
          height: cutOutSize,
        ),
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final center = Offset(rect.width / 2, rect.height / 2);
    final half = cutOutSize / 2;
    const cLen = 20.0;
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Corner markers
    void corner(Offset a, Offset b, Offset c) {
      canvas
        ..drawLine(a, b, paint)
        ..drawLine(b, c, paint);
    }

    corner(
      Offset(center.dx - half, center.dy - half + cLen),
      Offset(center.dx - half, center.dy - half),
      Offset(center.dx - half + cLen, center.dy - half),
    );
    corner(
      Offset(center.dx + half - cLen, center.dy - half),
      Offset(center.dx + half, center.dy - half),
      Offset(center.dx + half, center.dy - half + cLen),
    );
    corner(
      Offset(center.dx - half, center.dy + half - cLen),
      Offset(center.dx - half, center.dy + half),
      Offset(center.dx - half + cLen, center.dy + half),
    );
    corner(
      Offset(center.dx + half - cLen, center.dy + half),
      Offset(center.dx + half, center.dy + half),
      Offset(center.dx + half, center.dy + half - cLen),
    );
  }

  @override
  ShapeBorder scale(double t) => _ScannerOverlayShape(
    borderColor: borderColor,
    borderWidth: borderWidth * t,
    overlayColor: overlayColor,
    cutOutSize: cutOutSize * t,
  );
}
