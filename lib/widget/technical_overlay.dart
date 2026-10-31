import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// Compact, theme-aware playback details panel.
class TechnicalOverlay extends StatelessWidget {
  const TechnicalOverlay({
    super.key,
    required this.stats,
    required this.onClose,
  });

  final Map<String, String> stats;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppPanel(
      padding: const EdgeInsets.all(DS.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Playback details',
                  style: AppTextStyles.title.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: AppTextStyles.titleFontWeight,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close playback details',
                onPressed: onClose,
                icon: Icon(LucideIcons.x, color: tokens.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: DS.s8),
          Expanded(
            child: ListView.separated(
              itemCount: stats.length,
              separatorBuilder: (_, _) => const SizedBox(height: DS.s12),
              itemBuilder: (context, index) {
                final key = stats.keys.elementAt(index);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        key,
                        style: AppTextStyles.caption.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        stats[key] ?? 'Unavailable',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
