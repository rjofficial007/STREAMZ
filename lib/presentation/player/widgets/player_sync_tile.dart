import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/player/widgets/player_action_button.dart';

/// PlayerSyncTile provides controls to adjust audio or subtitle sync offsets.
/// It features clear, focusable minus/plus controls for touch and TV remotes.
class PlayerSyncTile extends StatelessWidget {
  const PlayerSyncTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isTV = false,
  });
  final String label;
  final double value;
  final Function(double) onChanged;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Scale properties based on platform
    final padding = isTV ? 40.0 : 16.0;
    final labelSize = isTV ? 16.0 : 13.0;
    final valueSize = isTV ? 32.0 : 16.0;
    final btnSize = isTV ? 64.0 : 48.0;
    final spacing = isTV ? 24.0 : 12.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(DS.radius(16)),
        border: Border.all(color: tokens.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.style(
              color: tokens.textMuted,
              fontSize: labelSize,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              _SyncActionBtn(
                icon: LucideIcons.minus,
                label: 'Decrease ${label.toLowerCase()}',
                size: btnSize,
                isTV: isTV,
                onTap: () => onChanged(value - 0.1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${value.toStringAsFixed(1)} s',
                    style: AppTextStyles.style(
                      color: tokens.textPrimary,
                      fontSize: valueSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              _SyncActionBtn(
                icon: LucideIcons.plus,
                label: 'Increase ${label.toLowerCase()}',
                size: btnSize,
                isTV: isTV,
                onTap: () => onChanged(value + 0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Private internal button for sync adjustments with focus support.
class _SyncActionBtn extends StatelessWidget {
  const _SyncActionBtn({
    required this.icon,
    required this.label,
    required this.size,
    required this.isTV,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final double size;
  final bool isTV;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PlayerActionButton(
    icon: icon,
    label: label,
    size: size,
    isTV: isTV,
    onPressed: onTap,
  );
}
