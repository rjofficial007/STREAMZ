import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// LowFiIndicator notifies the user when the stream has entered "Low-Fi" recovery mode.
/// This happens when the local network signal is too weak for high-bitrate playback.
class LowFiIndicator extends StatelessWidget {
  const LowFiIndicator({super.key, this.isTV = false});
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final bottomPadding = isTV ? 200.0 : 100.0;
    final leftPadding = isTV ? 60.0 : 20.0;
    final fontSize = isTV ? 16.0 : 12.0;

    return Positioned(
      bottom: bottomPadding,
      left: leftPadding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.surface3,
          borderRadius: BorderRadius.circular(DS.radius(14)),
          border: Border.all(color: tokens.borderStrong),
        ),
        child: Text(
          isTV ? 'LOW-FI SIGNAL RECOVERY ACTIVATED' : 'LOW-FI SIGNAL RECOVERY',
          style: AppTextStyles.style(color: tokens.textPrimary, fontSize: fontSize, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
