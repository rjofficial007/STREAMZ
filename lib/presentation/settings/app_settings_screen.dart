import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/core/theme/theme_service.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ThemeService>();
    final size = MediaQuery.sizeOf(context);
    final isTV = DS.isTV(context);
    final horizontalPadding = isTV ? 48.0 : (size.width < 600 ? 16.0 : 32.0);

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            AppSliverAppBar(
              pinned: true,
              title: Text(
                'Appearance',
                style: AppTextStyles.titleLarge.copyWith(
                  color: context.tokens.textPrimary,
                ),
              ),
              leading: AppBackButton(onPressed: () => context.pop()),
              actions: [
                IconButton(
                  tooltip: 'Reset appearance',
                  onPressed: () => unawaited(settings.resetAppearance()),
                  icon: const Icon(LucideIcons.rotateCcw),
                ),
                const SizedBox(width: DS.s8),
              ],
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      DS.s24,
                      horizontalPadding,
                      DS.s80,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Make ${AppStrings.appTitle} yours',
                          style: AppTextStyles.heading(
                            isTV ? 32 : 26,
                            color: context.tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: DS.s8),
                        Text(
                          'Customize type, glow, and corner rounding. Saved on this device.',
                          style: AppTextStyles.body.copyWith(
                            color: context.tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: DS.s32),
                        _SettingsSection(
                          title: 'Font family',
                          description: 'Choose the app typeface.',
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 700
                                  ? 4
                                  : 2;
                              final width =
                                  (constraints.maxWidth - DS.s12 * (columns - 1)) /
                                  columns;
                              return Wrap(
                                spacing: DS.s12,
                                runSpacing: DS.s12,
                                children: AppFontFamily.values
                                    .map(
                                      (font) => SizedBox(
                                        width: width,
                                        child: _FontChoice(
                                          font: font,
                                          selected: settings.fontFamily == font,
                                          onTap: () => unawaited(
                                            settings.setFontFamily(font),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: DS.s32),
                        _SettingsSection(
                          title: 'Title weight',
                          description: 'Adjust heading weight.',
                          child: _TitleWeightControl(
                            value: settings.titleWeight,
                            onChanged: (value) => settings.previewTitleWeight(
                              AppTitleWeight.values[value.round()],
                            ),
                            onChangeEnd: (_) =>
                                unawaited(settings.persistTitleWeight()),
                          ),
                        ),
                        const SizedBox(height: DS.s32),
                        _SettingsSection(
                          title: 'Scaffold glow',
                          description: 'Choose the top scaffold glow color.',
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  const columns = 3;
                                  const spacing = DS.s8;
                                  final itemWidth =
                                      (constraints.maxWidth -
                                          spacing * (columns - 1)) /
                                      columns;
                                  return Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    children: AppGlowColor.values
                                        .map(
                                          (glow) => SizedBox(
                                            width: itemWidth,
                                            height: 92,
                                            child: _GlowChoice(
                                              glow: glow,
                                              selected:
                                                  settings.glowColor == glow,
                                              onTap: () => unawaited(
                                                settings.setGlowColor(glow),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: DS.s32),
                        _SettingsSection(
                          title: 'Corner radius',
                          description: 'Set the shared corner radius.',
                          child: _CornerRadiusControl(
                            value: settings.cornerRadius,
                            onChanged: settings.previewCornerRadius,
                            onChangeEnd: (_) =>
                                unawaited(settings.persistCornerRadius()),
                          ),
                        ),
                        const SizedBox(height: DS.s32),
                        _SettingsSection(
                          title: 'Preview',
                          description: 'Preview your choices together.',
                          child: _AppearancePreview(
                            fontFamily: settings.fontFamily,
                            glowColor: settings.glowColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: AppTextStyles.title.copyWith(color: context.tokens.textPrimary),
      ),
      const SizedBox(height: DS.s4),
      Text(
        description,
        style: AppTextStyles.supporting.copyWith(
          color: context.tokens.textMuted,
        ),
      ),
      const SizedBox(height: DS.s16),
      child,
    ],
  );
}

class _FontChoice extends StatelessWidget {
  const _FontChoice({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final AppFontFamily font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${font.label} font${selected ? ', selected' : ''}',
    child: AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DS.s16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                font.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: context.tokens.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: DS.s8),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              size: 18,
              color: selected
                  ? context.tokens.accent
                  : context.tokens.textMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _GlowChoice extends StatelessWidget {
  const _GlowChoice({
    required this.glow,
    required this.selected,
    required this.onTap,
  });

  final AppGlowColor glow;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${glow.label} scaffold glow${selected ? ', selected' : ''}',
    child: AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s4,
          vertical: DS.s8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: glow.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: glow.color.withValues(alpha: 0.48),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : const [],
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: DS.s4),
            Text(
              glow.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: context.tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CornerRadiusControl extends StatelessWidget {
  const _CornerRadiusControl({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Corner radius',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: context.tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                '${value.round()} dp',
                style: AppTextStyles.labelMd.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 32,
            divisions: 32,
            label: '${value.round()} dp',
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Square',
                style: AppTextStyles.caption.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
              Text(
                'Soft',
                style: AppTextStyles.caption.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TitleWeightControl extends StatelessWidget {
  const _TitleWeightControl({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final AppTitleWeight value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Title text weight',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: context.tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                value.label,
                style: AppTextStyles.labelMd.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
          Slider(
            value: value.index.toDouble(),
            min: 0,
            max: (AppTitleWeight.values.length - 1).toDouble(),
            divisions: AppTitleWeight.values.length - 1,
            label: value.label,
            semanticFormatterCallback: (index) =>
                AppTitleWeight.values[index.round()].label,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Light',
                style: AppTextStyles.caption.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
              Text(
                'Bold',
                style: AppTextStyles.caption.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({
    required this.fontFamily,
    required this.glowColor,
  });

  final AppFontFamily fontFamily;
  final AppGlowColor glowColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(DS.s20),
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -1.15),
        radius: 1.2,
        colors: [
          glowColor.color.withValues(alpha: 0.38),
          context.tokens.surface1,
        ],
      ),
      borderRadius: BorderRadius.circular(DS.radiusLg),
      border: Border.all(color: context.tokens.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.appTitle,
          style: AppTextStyles.display(
            30,
            spacing: 1,
            color: context.tokens.textPrimary,
          ),
        ),
        const SizedBox(height: DS.s4),
        Text(
          'Your media library',
          style: AppTextStyles.titleLarge.copyWith(
            color: context.tokens.textPrimary,
          ),
        ),
        const SizedBox(height: DS.s4),
        Text(
          'Your media, shared simply.',
          style: AppTextStyles.body.copyWith(color: context.tokens.textMuted),
        ),
        const SizedBox(height: DS.s16),
        Text(
          '${fontFamily.label} · The quick brown fox jumps over the lazy dog.',
          style: AppTextStyles.supporting.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
      ],
    ),
  );
}
