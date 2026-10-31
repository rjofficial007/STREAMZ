import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// Summary heading that stacks its trailing status before it can overflow.
class AppSummaryHeader extends StatelessWidget {
  const AppSummaryHeader({
    super.key,
    required this.title,
    required this.titleStyle,
    required this.trailing,
    this.stackBelowWidth = 440,
  });

  final String title;
  final TextStyle titleStyle;
  final Widget trailing;
  final double stackBelowWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 17;
      final heading = Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      );

      if (constraints.maxWidth < stackBelowWidth || largeText) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            const SizedBox(height: DS.s12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Align(alignment: Alignment.centerLeft, child: trailing),
            ),
          ],
        );
      }

      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: DS.s12),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      );
    },
  );
}

/// Compact summary legend that moves its value below the label when space is tight.
class AppSummaryLegend extends StatelessWidget {
  const AppSummaryLegend({
    super.key,
    required this.label,
    required this.value,
    required this.markerColor,
  });

  final String label;
  final String value;
  final Color markerColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 17;
        final labelRow = Row(
          children: [
            Container(width: 8, height: 8, color: markerColor),
            const SizedBox(width: DS.s8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: tokens.textMuted),
              ),
            ),
          ],
        );
        final valueText = Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
          ),
        );

        if (constraints.maxWidth < 160 || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelRow,
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: valueText,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: labelRow),
            const SizedBox(width: DS.s8),
            Flexible(child: valueText),
          ],
        );
      },
    );
  }
}
