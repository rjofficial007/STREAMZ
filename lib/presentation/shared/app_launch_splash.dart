import 'dart:async';

import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/shared/app_brand_icon.dart';

/// Covers the mounted route while the brand animation plays.
class AppLaunchSplash extends StatefulWidget {
  const AppLaunchSplash({super.key, required this.child, this.topColor});

  final Widget child;
  final Color? topColor;

  @override
  State<AppLaunchSplash> createState() => _AppLaunchSplashState();
}

class _AppLaunchSplashState extends State<AppLaunchSplash>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1500);

  late final AnimationController _controller;
  late final Animation<double> _markOpacity;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _exitOpacity;
  Timer? _reducedMotionTimer;
  bool _isComplete = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _isComplete = true);
        }
      });
    _markOpacity = _reveal(0.04, 0.30);
    _wordmarkOpacity = _reveal(0.14, 0.42);
    _taglineOpacity = _reveal(0.24, 0.52);
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.82, 1, curve: Curves.easeInOut),
      ),
    );
  }

  Animation<double> _reveal(double begin, double end) => CurvedAnimation(
    parent: _controller,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 0.72;
      _reducedMotionTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _isComplete = true);
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _reducedMotionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final markSize = (shortestSide * 0.13).clamp(42.0, 70.0);
    final wordmarkSize = (shortestSide * 0.115).clamp(38.0, 68.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: !_isComplete, child: widget.child),
        if (!_isComplete)
          Positioned.fill(
            child: AbsorbPointer(
              child: FadeTransition(
                opacity: _exitOpacity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppBackdropSurface(topColor: widget.topColor),
                    SafeArea(
                      child: Semantics(
                        label:
                            '${AppStrings.appTitle}. Your media, shared simply.',
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _revealWidget(
                                  _markOpacity,
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: (widget.topColor ??
                                                  DS.scaffoldGlowColor)
                                              .withValues(alpha: 0.18),
                                          blurRadius: 42,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: AppBrandIcon(
                                      size: markSize,
                                      transparent: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 26),
                                _revealWidget(
                                  _wordmarkOpacity,
                                  Text(
                                    AppStrings.appTitle,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.display(
                                      wordmarkSize,
                                      spacing: 1.2,
                                      color: const Color(0xFFE4E5E9),
                                    ).copyWith(
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _revealWidget(
                                  _taglineOpacity,
                                  Text(
                                    'Your media, shared simply.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.style(
                                      fontSize: (shortestSide * 0.037).clamp(
                                        14.0,
                                        20.0,
                                      ),
                                      color: DS.textSecondary,
                                      fontWeight: FontWeight.w300,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _revealWidget(Animation<double> animation, Widget child) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(
            Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero),
          ),
          child: child,
        ),
      );
}
