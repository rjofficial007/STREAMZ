import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// Shared live-station card for mobile and TV rails or grid layouts.
class AppLiveStationCard extends StatelessWidget {
  const AppLiveStationCard({
    super.key,
    required this.title,
    required this.trackTitle,
    required this.onTap,
    this.liveLabel = 'Live',
    this.nowPlayingLabel = 'Now playing',
    this.width,
    this.height,
    this.onFocusChanged,
    this.focusNode,
  });

  final String title;
  final String trackTitle;
  final String liveLabel;
  final String nowPlayingLabel;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final ValueChanged<bool>? onFocusChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      width: width,
      height: height,
      child: AppCard(
        onTap: onTap,
        onFocusChanged: onFocusChanged,
        focusNode: focusNode,
        child: Padding(
          padding: const EdgeInsets.all(DS.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading(
                        18,
                        spacing: -0.2,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s8,
                      vertical: DS.s4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      borderRadius: BorderRadius.circular(DS.radiusLg),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 7,
                          color: tokens.success,
                        ),
                        const SizedBox(width: DS.s4),
                        Text(
                          liveLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nowPlayingLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: DS.s4),
                  Text(
                    trackTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
