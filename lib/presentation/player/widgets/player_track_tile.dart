import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// PlayerTrackTile is an adaptive selection tile for media tracks (Audio, Subtitles)
/// and Broadcast Stations. It handles both touch (Mobile) and D-Pad (TV) interactions.
class PlayerTrackTile extends StatelessWidget {
  const PlayerTrackTile({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isTV = false,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final card = AppCard(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: isTV ? DS.s20 : DS.s12,
        ),
        child: Semantics(
          selected: isActive,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: tokens.textPrimary,
                    fontSize: isTV ? 18 : null,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isActive)
                Icon(
                  LucideIcons.circleCheck,
                  color: tokens.accent,
                  size: isTV ? 24 : 20,
                ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s4),
      child: isTV
          ? Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) => handleTVSelectKey(event, onTap),
              child: card,
            )
          : card,
    );
  }
}
