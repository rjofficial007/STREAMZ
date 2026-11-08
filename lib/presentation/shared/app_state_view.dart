import 'package:flutter/material.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/core/theme/theme_tokens.dart';

enum AppStateKind { loading, empty, error }

/// Responsive, screen-reader friendly content for loading, empty, and error states.
class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.title,
    this.description,
    this.kind = AppStateKind.empty,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.maxWidth = 560,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide both actionLabel and onAction, or neither.',
       ),
       assert(maxWidth > 0, 'maxWidth must be greater than zero.');

  final AppStateKind kind;
  final String title;
  final String? description;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<StreamzThemeExtension>()!;
    final textTheme = theme.textTheme;
    final message = description?.trim();
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    final isLoading = kind == AppStateKind.loading;
    final isError = kind == AppStateKind.error;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          Semantics(
            label: title,
            liveRegion: true,
            child: SizedBox.square(
              dimension: 36,
              child: ExcludeSemantics(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.accent,
                ),
              ),
            ),
          )
        else
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.surface1,
                shape: BoxShape.circle,
                border: Border.all(
                  color: tokens.border.withValues(alpha: 0.65),
                ),
              ),
              child: SizedBox.square(
                dimension: 64,
                child: Icon(
                  icon ?? _defaultIcon,
                  color: tokens.textMuted,
                  size: 28,
                ),
              ),
            ),
          ),
        const SizedBox(height: DS.s20),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(color: tokens.textPrimary),
          ),
        ),
        if (message != null && message.isNotEmpty) ...[
          const SizedBox(height: DS.s8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: DS.s24),
          Align(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: DS
                .hPad(MediaQuery.sizeOf(context).width)
                .clamp(DS.s16, DS.s48)
                .toDouble(),
            vertical: DS.s32,
          ),
          child: isLoading
              ? content
              : Semantics(container: true, liveRegion: isError, child: content),
        ),
      ),
    );
  }

  IconData get _defaultIcon => switch (kind) {
    AppStateKind.loading => Icons.hourglass_empty_rounded,
    AppStateKind.empty => Icons.inbox_outlined,
    AppStateKind.error => Icons.error_outline_rounded,
  };
}

/// Fills the remaining scroll viewport with an [AppStateView].
class AppStateSliver extends StatelessWidget {
  const AppStateSliver({super.key, required this.state});

  final AppStateView state;

  @override
  Widget build(BuildContext context) =>
      SliverFillRemaining(hasScrollBody: false, child: state);
}
