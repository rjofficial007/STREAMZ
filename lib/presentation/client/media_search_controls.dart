import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/client/media_title_search.dart';

/// Shared filter and sort controls for mobile and TV media search.
class MediaSearchControls extends StatelessWidget {
  const MediaSearchControls({
    super.key,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final MediaSearchFilter filter;
  final MediaSearchSort sort;
  final ValueChanged<MediaSearchFilter> onFilterChanged;
  final ValueChanged<MediaSearchSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(
      spacing: DS.s8,
      runSpacing: DS.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final option in MediaSearchFilter.values)
          ChoiceChip(
            label: Text(option.label),
            selected: filter == option,
            onSelected: (_) => onFilterChanged(option),
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            backgroundColor: tokens.surface1,
            selectedColor: tokens.surface3,
            side: BorderSide(
              color: filter == option ? tokens.borderStrong : tokens.border,
            ),
            labelStyle: AppTextStyles.caption.copyWith(
              color: tokens.textPrimary,
              fontWeight: filter == option ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        PopupMenuButton<MediaSearchSort>(
          tooltip: 'Sort results',
          onSelected: onSortChanged,
          itemBuilder: (context) => [
            for (final option in MediaSearchSort.values)
              PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    if (sort == option)
                      Icon(Icons.check_rounded, size: 18, color: tokens.accent)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: DS.s8),
                    Text(option.label),
                  ],
                ),
              ),
          ],
          child: Chip(
            avatar: Icon(Icons.sort_rounded, size: 18, color: tokens.textMuted),
            label: Text(sort.label),
            backgroundColor: tokens.surface1,
            side: BorderSide(color: tokens.border),
            labelStyle: AppTextStyles.caption.copyWith(
              color: tokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
