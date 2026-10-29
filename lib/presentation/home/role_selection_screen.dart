// presentation/home/role_selection_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/core/theme/theme_tokens.dart';
import 'package:streamz/domain/services/platform_service.dart';
import 'package:streamz/presentation/home/role_selection_screen_tv.dart';
import 'package:streamz/presentation/shared/app_brand_icon.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _navigating = false;

  Future<void> _handleServerTap() async {
    if (_navigating) return;
    setState(() => _navigating = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final platformSvc = sl<PlatformService>();

      if (!platformSvc.requiresPermissionScreen()) {
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
    if (DS.isTV(context)) return const RoleSelectionScreenTV();

    final tokens = context.tokens;
    return AppScaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _BrandLockup(tokens: tokens),
                            const SizedBox(height: 40),
                            _QuickActionCard(
                              label: 'Host server',
                              subLabel: 'Share your library on this network',
                              icon: LucideIcons.hardDrive,
                              onTap: _handleServerTap,
                            ),
                            const SizedBox(height: 12),
                            _QuickActionCard(
                              label: 'Join a server',
                              subLabel: 'Connect to a shared library',
                              icon: LucideIcons.wifiHigh,
                              onTap: _handleClientTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 8,
              child: IconButton(
                tooltip: 'Appearance settings',
                onPressed: () => context.push('/settings'),
                icon: const Icon(LucideIcons.settings2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.tokens});

  final StreamzThemeExtension tokens;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Column(
      children: [
        const AppBrandIcon(size: 64),
        const SizedBox(height: 24),
        Text(
          'STREAMZ',
          textAlign: TextAlign.center,
          style: AppTextStyles.style(
            color: tokens.textPrimary,
            fontSize: (width * 0.13).clamp(40.0, 60.0),
            fontWeight: FontWeight.w300,
            letterSpacing: 0.8,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your media, shared simply.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge.copyWith(
            color: tokens.textSecondary,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.subLabel,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tokens.surface2.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(DS.radius(14)),
              ),
              child: Icon(icon, size: 19, color: tokens.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.arrowUpRight, size: 17, color: tokens.textMuted),
          ],
        ),
      ),
    );
  }
}
