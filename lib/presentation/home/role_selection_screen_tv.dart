// presentation/home/role_selection_screen_tv.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/shared/app_brand_icon.dart';

class RoleSelectionScreenTV extends StatefulWidget {
  const RoleSelectionScreenTV({super.key});

  @override
  State<RoleSelectionScreenTV> createState() => _RoleSelectionScreenTVState();
}

class _RoleSelectionScreenTVState extends State<RoleSelectionScreenTV> {
  bool _navigating = false;

  Future<void> _handleServerTap() async {
    if (_navigating) return;
    setState(() => _navigating = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final isAutoGrantPlatform =
          kIsWeb ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux;

      if (isAutoGrantPlatform) {
        await prefs.setBool('permissions_granted', true);
      }

      final granted = prefs.getBool('permissions_granted') ?? false;
      if (!mounted) return;

      if (granted) {
        unawaited(context.push('/server'));
      } else {
        unawaited(context.push('/server/permissions'));
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  void _handleClientTap() {
    if (_navigating) return;
    setState(() => _navigating = true);
    context.push('/client/connect').whenComplete(() {
      if (mounted) setState(() => _navigating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: DS.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TVActionCard(
                            label: 'Host server',
                            subLabel: 'Share your library on this network',
                            icon: LucideIcons.hardDrive,
                            onTap: _handleServerTap,
                            autofocus: true,
                          ),
                        ),
                        SizedBox(width: (size.width * 0.025).clamp(24.0, 48.0)),
                        Expanded(
                          child: _TVActionCard(
                            label: 'Join a server',
                            subLabel: 'Connect to a shared library',
                            icon: LucideIcons.wifiHigh,
                            onTap: _handleClientTap,
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = (size.width * 0.05).clamp(32.0, 88.0);
    final verticalPad = (size.height * 0.035).clamp(20.0, 40.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPad,
        verticalPad,
        horizontalPad,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppBrandIcon(
            size: (size.height * 0.085).clamp(44.0, 64.0).toDouble(),
          ),
          SizedBox(width: (size.width * 0.015).clamp(16.0, 28.0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'STREAMZ',
                  style: AppTextStyles.style(
                    color: tokens.textPrimary,
                    fontSize: (size.width * 0.03).clamp(32.0, 52.0),
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your media, shared simply.',
                  style: AppTextStyles.style(
                    color: tokens.textSecondary,
                    fontSize: (size.width * 0.011).clamp(14.0, 18.0),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          Focus(
            onKeyEvent: (_, event) => handleTVSelectKey(
              event,
              () => context.push('/settings'),
            ),
            child: IconButton(
              tooltip: 'Appearance settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(LucideIcons.settings2),
            ),
          ),
        ],
      ),
    );
  }
}

class _TVActionCard extends StatefulWidget {
  const _TVActionCard({
    required this.label,
    required this.subLabel,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
  });

  final String label;
  final String subLabel;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_TVActionCard> createState() => _TVActionCardState();
}

class _TVActionCardState extends State<_TVActionCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        if (focused) handleTVFocusScroll(focused, context);
      },
      onKeyEvent: (_, event) => handleTVSelectKey(event, widget.onTap),
      child: AnimatedScale(
        scale: _isFocused ? 1.02 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(DS.radius(24)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: (size.height * 0.43).clamp(250.0, 380.0),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _isFocused
                    ? tokens.surface2.withValues(alpha: 0.96)
                    : tokens.surface1.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(DS.radius(24)),
                border: Border.all(
                  color: _isFocused
                      ? tokens.focusColor.withValues(alpha: 0.82)
                      : tokens.border.withValues(alpha: 0.72),
                  width: _isFocused ? 2 : 1,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: tokens.accent.withValues(alpha: 0.08),
                          blurRadius: 36,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: tokens.surface3.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(DS.radius(22)),
                    ),
                    child: Icon(
                      widget.icon,
                      color: tokens.textPrimary,
                      size: 30,
                    ),
                  ),
                  SizedBox(height: (size.height * 0.035).clamp(20.0, 32.0)),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.style(
                      color: tokens.textPrimary,
                      fontSize: (size.width * 0.022).clamp(24.0, 40.0),
                      fontWeight: AppTextStyles.titleFontWeight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subLabel,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.style(
                      color: tokens.textSecondary,
                      fontSize: (size.width * 0.010).clamp(14.0, 18.0),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
