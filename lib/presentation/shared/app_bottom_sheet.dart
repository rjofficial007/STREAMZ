import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// Opens a modal using the app's shared surface, shape, drag handle and sizing.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool enableDrag = true,
}) => showModalBottomSheet<T>(
  context: context,
  builder: builder,
  isScrollControlled: isScrollControlled,
  useSafeArea: useSafeArea,
  enableDrag: enableDrag,
  backgroundColor: context.tokens.surface1,
  clipBehavior: Clip.antiAlias,
  constraints: const BoxConstraints(maxWidth: 880),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusLg)),
  ),
);

/// Consistent sheet heading with optional supporting text and actions.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.horizontalPadding = DS.s24,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = trailing != null &&
            (constraints.maxWidth < 520 ||
                MediaQuery.textScalerOf(context).scale(14) > 17);
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading(
                18,
                spacing: -0.2,
                color: tokens.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: DS.s4),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.text(13, color: tokens.textMuted),
              ),
            ],
          ],
        );
        final leading = icon == null
            ? null
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(DS.radius(14)),
                ),
                child: Icon(icon, size: 20, color: tokens.textSecondary),
              );

        if (compact) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              DS.s16,
              horizontalPadding,
              DS.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      leading,
                      const SizedBox(width: DS.s12),
                    ],
                    Expanded(child: titleBlock),
                  ],
                ),
                const SizedBox(height: DS.s8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: trailing,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            DS.s16,
            horizontalPadding,
            DS.s16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: DS.s12),
              ],
              Expanded(child: titleBlock),
              if (trailing != null) ...[
                const SizedBox(width: DS.s8),
                Flexible(child: trailing!),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Focusable, touch-friendly option row shared by compact action sheets.
class AppSheetOption extends StatelessWidget {
  const AppSheetOption({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s4),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(DS.radius(14)),
                ),
                child: Icon(icon, size: 20, color: tokens.textSecondary),
              ),
              const SizedBox(width: DS.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DS.s4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.supporting.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: DS.s12),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: tokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
