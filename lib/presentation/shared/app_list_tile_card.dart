import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// Shared, focusable row card for media, history, and live station lists.
class AppListTileCard extends StatelessWidget {
  const AppListTileCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s8),
      child: AppCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s16,
            vertical: DS.s12,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? tokens.accent.withValues(alpha: 0.12)
                      : tokens.surface2,
                  borderRadius: BorderRadius.circular(DS.radius(14)),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: isActive ? tokens.accent : tokens.textSecondary,
                ),
              ),
              const SizedBox(width: DS.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: DS.s4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.supporting.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive || trailingIcon != null) ...[
                const SizedBox(width: DS.s12),
                Icon(
                  isActive ? Icons.check_circle_rounded : trailingIcon,
                  size: 20,
                  color: isActive ? tokens.accent : tokens.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
