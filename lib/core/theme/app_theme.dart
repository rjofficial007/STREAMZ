// core/theme/app_theme.dart
// ============================================================================
// STREAMZ — Master Design System & UI Components (Production-Fixed)
//
// BUG FIXED:
//   handleTVFocusScroll called Scrollable.ensureVisible synchronously during
//   a focus-change callback. On the very first frame after navigation, the
//   widget may not yet be attached to a scroll ancestor, causing:
//     "Scrollable.ensureVisible called with a context that does not contain a Scrollable"
//   Fixed by wrapping the call in WidgetsBinding.instance.addPostFrameCallback
//   so it executes after the current frame's layout pass completes.
// ============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';

import 'design_tokens.dart';

abstract final class AppTheme {
  static const double bpMobile = DS.bpMobile;
  static const double bpDesktop = DS.bpTablet;

  static const Color background = DS.bg;
  static const Color surfaceDark = DS.surface1;
  static const Color surfaceLight = DS.surface2;
  static const Color surfaceHighlight = DS.surface3;
  static const Color accent = DS.accent;
  static const Color borderLine = DS.borderDefault;
  static const Color borderHover = DS.borderStrong;
  static const Color textPrimary = DS.textPrimary;
  static const Color textSecondary = DS.textSecondary;
  static const Color textMuted = DS.textMuted;

  static ThemeData get theme => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: DS.bg,
    primaryColor: DS.accent,
    canvasColor: DS.surface1,
    appBarTheme: AppBarTheme(
      backgroundColor: DS.bg,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: DS.textPrimary),
      shape: const Border(bottom: BorderSide(color: DS.borderDefault, width: 1)),
      titleTextStyle: GoogleFonts.dmMono(fontSize: 14, letterSpacing: 3, color: DS.textPrimary, fontWeight: FontWeight.bold),
    ),
    colorScheme: const ColorScheme.dark(primary: DS.accent, secondary: DS.accent, surface: DS.surface1, onSurface: DS.textPrimary),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.barlowCondensed(fontSize: 80, fontWeight: FontWeight.w900, color: DS.textPrimary, letterSpacing: -2, height: 0.9),
      displayMedium: GoogleFonts.barlowCondensed(fontSize: 48, fontWeight: FontWeight.w900, color: DS.textPrimary, letterSpacing: -1, height: 1.0),
      headlineSmall: GoogleFonts.barlowCondensed(fontSize: 32, fontWeight: FontWeight.w700, color: DS.textPrimary, letterSpacing: -0.5, height: 1.1),
      titleMedium: GoogleFonts.barlowCondensed(fontSize: 24, fontWeight: FontWeight.w700, color: DS.textPrimary, letterSpacing: 1.0),
      labelSmall: GoogleFonts.dmMono(fontSize: 11, letterSpacing: 3, color: DS.textMuted, fontWeight: FontWeight.w500),
      labelMedium: GoogleFonts.dmMono(fontSize: 13, letterSpacing: 2, color: DS.textPrimary, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.barlow(fontSize: 15, fontWeight: FontWeight.w300, color: DS.textSecondary, height: 1.6),
      bodyMedium: GoogleFonts.barlow(fontSize: 13, fontWeight: FontWeight.w300, color: DS.textSecondary, height: 1.6),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class Responsive {
  static bool isMobile(BuildContext ctx) => MediaQuery.sizeOf(ctx).width <= DS.bpMobile;
  static bool isDesktop(BuildContext ctx) => MediaQuery.sizeOf(ctx).width >= DS.bpTablet;
  static bool isTV(BuildContext ctx) => MediaQuery.sizeOf(ctx).width >= DS.bpTV;
  static double hPad(BuildContext ctx) => DS.hPad(MediaQuery.sizeOf(ctx).width);

  static T value<T>(BuildContext ctx, {required T mobile, T? tablet, required T desktop}) {
    final w = MediaQuery.sizeOf(ctx).width;
    if (w >= DS.bpTablet) return desktop;
    if (w > DS.bpMobile && tablet != null) return tablet;
    return mobile;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV FOCUS HELPERS
// ─────────────────────────────────────────────────────────────────────────────

KeyEventResult handleTVSelectKey(KeyEvent event, VoidCallback? onTap) {
  if (onTap != null &&
      event is KeyDownEvent &&
      (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
    onTap();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// FIX: Wraps Scrollable.ensureVisible in addPostFrameCallback to prevent
/// "context does not contain a Scrollable" crash on frame 1.
void handleTVFocusScroll(bool hasFocus, BuildContext context) {
  if (!hasFocus) return;
  // Defer until after the current frame's layout so the widget is fully
  // attached to its scroll ancestor before we request scroll.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Guard: context may have been unmounted by the time the callback fires.
    if (!context.mounted) return;
    try {
      Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    } catch (_) {
      // No ancestor Scrollable — safe to ignore (e.g. full-screen TV cards).
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CORE UI COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  const AppScaffold({super.key, required this.body, this.appBar, this.floatingActionButton, this.floatingActionButtonLocation, this.bottomNavigationBar});

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    backgroundColor: DS.bg,
    appBar: appBar,
    body: body,
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: floatingActionButtonLocation ?? FloatingActionButtonLocation.centerFloat,
    bottomNavigationBar: bottomNavigationBar,
  );
}

class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AppCard({super.key, required this.child, this.onTap, this.onLongPress});

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onTap?.call();
          return null;
        },
      ),
    },
    child: Focus(
      onFocusChange: (val) {
        setState(() => _isFocused = val);
        handleTVFocusScroll(val, context);
      },
      onKeyEvent: (node, event) => handleTVSelectKey(event, widget.onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _isFocused ? DS.surface3 : DS.surface1,
          border: Border.all(color: _isFocused ? DS.accent : DS.borderDefault, width: _isFocused ? 3.0 : 1.0),
          boxShadow: _isFocused ? [const BoxShadow(color: DS.accent, offset: Offset(4, 4))] : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(onTap: widget.onTap, onLongPress: widget.onLongPress, onHover: (val) => setState(() => _isFocused = val), child: widget.child),
        ),
      ),
    ),
  );
}

class BrutalistBlock extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  const BrutalistBlock({super.key, required this.child, required this.padding, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? DS.surface1,
      border: Border.all(color: borderColor ?? DS.borderDefault, width: 1),
    ),
    child: child,
  );
}

class BrutalistToggle extends StatelessWidget {
  final bool value;
  final bool isMobile;

  const BrutalistToggle({super.key, required this.value, required this.isMobile});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: isMobile ? 32 : 40,
    height: isMobile ? 16 : 20,
    decoration: BoxDecoration(
      color: value ? DS.accent : Colors.transparent,
      border: Border.all(color: value ? DS.accent : DS.textMuted, width: 2),
    ),
    child: Stack(
      children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: isMobile ? 10 : 12, height: isMobile ? 10 : 12, margin: const EdgeInsets.symmetric(horizontal: 2), color: value ? DS.bg : DS.textMuted),
        ),
      ],
    ),
  );
}

class BrutalistToggleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final bool isMobile;
  final Function(bool) onChanged;

  const BrutalistToggleTile({super.key, required this.label, required this.icon, required this.value, required this.isMobile, required this.onChanged});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: DS.s16, vertical: isMobile ? DS.s8 : DS.s12),
      child: Row(
        children: [
          Icon(icon, color: DS.accent, size: isMobile ? 16 : 20),
          const SizedBox(width: DS.s16),
          Expanded(
            child: Text(label, style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 11 : 12)),
          ),
          BrutalistToggle(value: value, isMobile: isMobile),
        ],
      ),
    ),
  );
}

class CompactBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isLoading;
  final double height;

  const CompactBtn({super.key, required this.label, this.icon, required this.onTap, this.isPrimary = true, this.isLoading = false, this.height = 48});

  @override
  State<CompactBtn> createState() => _CompactBtnState();
}

class _CompactBtnState extends State<CompactBtn> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isPrimary ? DS.accent : Colors.transparent;
    final fg = widget.isPrimary ? DS.bg : DS.textPrimary;
    final border = widget.isPrimary ? DS.accent : DS.borderDefault;

    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (!widget.isLoading) widget.onTap();
            return null;
          },
        ),
      },
      child: Focus(
        onFocusChange: (val) => setState(() => _isFocused = val),
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.isLoading ? null : widget.onTap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isFocused && !widget.isPrimary ? DS.surface3 : bg,
            border: Border.all(color: _isFocused ? DS.accent : border, width: widget.isPrimary ? 2 : 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onTap,
              child: Center(
                child: widget.isLoading
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[Icon(widget.icon, size: 16, color: fg), const SizedBox(width: DS.s8)],
                          Text(
                            widget.label.toUpperCase(),
                            style: GoogleFonts.dmMono(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 2, color: fg),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isLoading;
  final double height;

  const AppButton({super.key, required this.label, this.icon, required this.onTap, this.isPrimary = true, this.isLoading = false, this.height = 54});

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isPrimary ? DS.accent : Colors.transparent;
    final fg = widget.isPrimary ? DS.bg : DS.textPrimary;
    final border = widget.isPrimary ? DS.accent : DS.borderDefault;

    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (!widget.isLoading) widget.onTap();
            return null;
          },
        ),
      },
      child: Focus(
        onFocusChange: (val) {
          setState(() => _isFocused = val);
          handleTVFocusScroll(val, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.isLoading ? null : widget.onTap),
        child: GestureDetector(
          onTap: widget.isLoading ? null : widget.onTap,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isFocused = true),
            onExit: (_) => setState(() => _isFocused = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: widget.height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isFocused ? (widget.isPrimary ? Colors.white70 : DS.surface3) : bg,
                border: Border.all(color: _isFocused ? DS.accent : border, width: _isFocused ? 3 : 1),
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[Icon(widget.icon, size: 16, color: fg), const SizedBox(width: DS.s12)],
                          Text(
                            widget.label.toUpperCase(),
                            style: GoogleFonts.dmMono(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 3, color: fg),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? activeColor;
  final Color? activeFg;

  const StatusBadge({super.key, required this.label, this.isActive = false, this.activeColor, this.activeFg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    color: isActive ? (activeColor ?? DS.accent) : DS.surface3,
    child: Text(
      label.toUpperCase(),
      style: GoogleFonts.dmMono(fontSize: 9, fontWeight: FontWeight.bold, color: isActive ? (activeFg ?? DS.bg) : DS.textSecondary),
    ),
  );
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;

  const SkeletonBox({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: DS.surface3,
      border: Border.all(color: DS.borderDefault),
    ),
  );
}

class NetworkImageFade extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final IconData fallbackIcon;

  const NetworkImageFade({super.key, required this.url, this.fit = BoxFit.cover, this.fallbackIcon = LucideIcons.film});

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    fadeInDuration: const Duration(milliseconds: 300),
    placeholder: (_, _) => Container(
      color: DS.surface1,
      child: Center(child: Icon(fallbackIcon, color: Colors.white24, size: 32)),
    ),
    errorWidget: (_, _, _) => Container(
      color: DS.surface1,
      child: Center(child: Icon(fallbackIcon, color: Colors.white24, size: 32)),
    ),
  );
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

// ─────────────────────────────────────────────────────────────────────────────
// PLAYER COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class BrutalistPlayerBtn extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autoFocus;
  final bool isPrimary;

  const BrutalistPlayerBtn({super.key, required this.icon, required this.size, this.onTap, this.focusNode, this.autoFocus = false, this.isPrimary = false});

  @override
  State<BrutalistPlayerBtn> createState() => _BrutalistPlayerBtnState();
}

class _BrutalistPlayerBtnState extends State<BrutalistPlayerBtn> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final bg = _isFocused ? DS.accent : (widget.isPrimary ? DS.textPrimary : DS.surface1);
    final fg = _isFocused ? DS.bg : (widget.isPrimary ? DS.bg : DS.textPrimary);
    final borderColor = _isFocused ? DS.accent : DS.borderDefault;
    final shadowOffset = isMobile ? const Offset(4, 4) : const Offset(6, 6);
    final boxSize = (Responsive.isTV(context) || Responsive.isDesktop(context)) ? widget.size * 1.6 : widget.size * 2.0;

    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autoFocus,
        onFocusChange: (val) => setState(() => _isFocused = val),
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isFocused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              margin: EdgeInsets.only(right: _isFocused ? shadowOffset.dx : 0, bottom: _isFocused ? shadowOffset.dy : 0),
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: borderColor, width: _isFocused ? (isMobile ? 2 : 4) : (isMobile ? 1 : 2)),
                boxShadow: _isFocused ? [BoxShadow(color: DS.accent, offset: shadowOffset)] : [],
              ),
              child: Icon(widget.icon, size: widget.size, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

class BrutalistProgressBar extends StatelessWidget {
  final Player player;
  final bool compact;
  final bool isReadOnly;

  const BrutalistProgressBar({super.key, required this.player, this.compact = false, this.isReadOnly = false});

  String _fmt(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return '${d.inHours}:'
          '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
          '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.toString().padLeft(2, '0')}:'
        '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: player.stream.position,
    builder: (_, posSnap) => StreamBuilder<Duration>(
      stream: player.stream.duration,
      builder: (_, durSnap) {
        final pos = posSnap.data ?? Duration.zero;
        final dur = durSnap.data ?? Duration.zero;
        final maxVal = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
        final curVal = pos.inMilliseconds.toDouble().clamp(0.0, maxVal);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: compact ? 56 : 80,
              child: Text(_fmt(pos.inSeconds), style: AppTheme.theme.textTheme.titleMedium?.copyWith(fontSize: compact ? 12 : 16)),
            ),
            const SizedBox(width: DS.s16),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: compact ? 4 : 8,
                  activeTrackColor: isReadOnly ? Colors.orangeAccent : DS.accent,
                  inactiveTrackColor: DS.surface3,
                  thumbColor: isReadOnly ? Colors.transparent : DS.accent,
                  overlayShape: SliderComponentShape.noOverlay,
                  trackShape: const RectangularSliderTrackShape(),
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: isReadOnly ? 0 : 6),
                ),
                child: Slider(
                  value: curVal,
                  min: 0,
                  max: maxVal,
                  onChanged: isReadOnly ? null : (v) => player.seek(Duration(milliseconds: v.toInt())),
                ),
              ),
            ),
            const SizedBox(width: DS.s16),
            SizedBox(
              width: compact ? 56 : 80,
              child: Text(
                _fmt(dur.inSeconds),
                textAlign: TextAlign.right,
                style: AppTheme.theme.textTheme.labelMedium?.copyWith(color: DS.textMuted, fontSize: compact ? 12 : 16),
              ),
            ),
          ],
        );
      },
    ),
  );
}
