import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/player/playback_issue.dart';

class PlaybackRecoveryOverlay extends StatelessWidget {
  const PlaybackRecoveryOverlay({
    super.key,
    required this.issue,
    required this.isRecovering,
    required this.isRetryInFlight,
    required this.retryAttempt,
    required this.isTV,
    required this.onRetry,
    required this.onBack,
  });

  final PlaybackIssue issue;
  final bool isRecovering;
  final bool isRetryInFlight;
  final int retryAttempt;
  final bool isTV;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final status = isRetryInFlight
        ? 'Reopening the media stream…'
        : retryAttempt == 0
        ? 'Reconnecting to the media source…'
        : 'Retrying · attempt $retryAttempt';

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DS.s24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: AppPanel(
                  padding: const EdgeInsets.all(DS.s24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PLAYBACK DIAGNOSTIC',
                        style: AppTextStyles.text(
                          12,
                          color: tokens.textMuted,
                          weight: FontWeight.w600,
                          spacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: DS.s12),
                      Text(
                        issue.title,
                        style: AppTextStyles.heading(
                          isTV ? 30 : 24,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: DS.s12),
                      Text(
                        issue.description,
                        style: AppTextStyles.body.copyWith(
                          color: tokens.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      if (isRecovering) ...[
                        const SizedBox(height: DS.s16),
                        Row(
                          children: [
                            SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.accent,
                              ),
                            ),
                            const SizedBox(width: DS.s12),
                            Expanded(
                              child: Text(
                                status,
                                style: AppTextStyles.text(
                                  14,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: DS.s24),
                      Wrap(
                        spacing: DS.s12,
                        runSpacing: DS.s12,
                        children: [
                          ElevatedButton.icon(
                            autofocus: isTV,
                            onPressed: isRetryInFlight ? null : onRetry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back to library'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
