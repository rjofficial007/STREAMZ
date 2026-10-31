// core/theme/app_theme.dart
// ============================================================================
// STREAMZ — Master Design System & UI Components (Production-Fixed)
// ============================================================================

import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/core/theme/streamz_theme.dart';
import 'package:streamz/core/theme/theme_tokens.dart';

abstract final class AppTheme {
  static const double bpMobile = DS.bpMobile;
  static const double bpDesktop = DS.bpTablet;

  static ThemeData themeFor(
    StreamzTheme streamzTheme, {
    Color? scaffoldTopColor,
    double? cornerRadius,
  }) {
    final tokens = streamzTheme.tokens.copyWith(
      scaffoldTopColor: scaffoldTopColor,
      borderRadius: cornerRadius,
    );
    final baseTheme = ThemeData.dark();
    final fontFamily = AppTextStyles.style().fontFamily;

    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        fontFamily: fontFamily,
        decoration: TextDecoration.none,
      ),
      primaryColor: tokens.primary,
      canvasColor: tokens.surface1,
      extensions: [tokens],
      dividerColor: tokens.borderSubtle,
      cardTheme: CardThemeData(
        color: tokens.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.radius(18)),
          side: BorderSide(color: tokens.border.withValues(alpha: 0.55)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: tokens.textPrimary),
        titleTextStyle: AppTextStyles.style(
          fontSize: 18,
          letterSpacing: -0.2,
          color: tokens.textPrimary,
          fontWeight: AppTextStyles.titleFontWeight,
        ),
      ),
      iconTheme: IconThemeData(color: tokens.textPrimary),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.radius(18)),
          side: BorderSide(color: tokens.border.withValues(alpha: 0.7)),
        ),
        titleTextStyle: AppTextStyles.style(
          color: tokens.textPrimary,
          fontSize: 24,
          fontWeight: AppTextStyles.titleFontWeight,
          letterSpacing: 0.5,
        ),
        contentTextStyle: AppTextStyles.style(
          color: tokens.textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface1,
        modalBackgroundColor: tokens.surface1,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: tokens.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DS.radius(24)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: AppTextStyles.style(color: tokens.textMuted, fontSize: 14),
        labelStyle: AppTextStyles.style(
          color: tokens.textSecondary,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radius(14)),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radius(14)),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radius(14)),
          borderSide: BorderSide(color: tokens.focusColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radius(14)),
          borderSide: BorderSide(color: tokens.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radius(14)),
          borderSide: BorderSide(color: tokens.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.background,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radius(14)),
          ),
          textStyle: AppTextStyles.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: tokens.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radius(14)),
          ),
          textStyle: AppTextStyles.style(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radius(12)),
          ),
          textStyle: AppTextStyles.style(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radius(14)),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.accent,
        inactiveTrackColor: tokens.surface3,
        thumbColor: tokens.textPrimary,
        overlayColor: tokens.accent.withValues(alpha: 0.14),
        valueIndicatorColor: tokens.surface4,
        valueIndicatorTextStyle: AppTextStyles.caption.copyWith(
          color: tokens.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.surface3,
        contentTextStyle: AppTextStyles.style(
          color: tokens.textPrimary,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radius(14))),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
        linearTrackColor: tokens.surface3,
        circularTrackColor: tokens.surface3,
      ),
      colorScheme: (const ColorScheme.dark()).copyWith(
        primary: tokens.primary,
        onPrimary: tokens.background,
        onSecondary: tokens.background,
        error: tokens.error,
        onError: tokens.background,
        secondary: tokens.accent,
        surface: tokens.surface1,
        onSurface: tokens.textPrimary,
      ),
      textTheme: baseTheme.textTheme
          .apply(
            fontFamily: fontFamily,
            decoration: TextDecoration.none,
          )
          .copyWith(
            displayLarge: AppTextStyles.display(64, color: tokens.textPrimary),
            displayMedium: AppTextStyles.display(48, color: tokens.textPrimary),
            displaySmall: AppTextStyles.display(36, color: tokens.textPrimary),
            headlineLarge: AppTextStyles.heading(32, color: tokens.textPrimary),
            headlineMedium: AppTextStyles.headline.copyWith(
              color: tokens.textPrimary,
            ),
            headlineSmall: AppTextStyles.sectionTitle.copyWith(
              color: tokens.textPrimary,
            ),
            titleLarge: AppTextStyles.titleLarge.copyWith(
              color: tokens.textPrimary,
            ),
            titleMedium: AppTextStyles.title.copyWith(
              color: tokens.textPrimary,
            ),
            titleSmall: AppTextStyles.bodyLarge.copyWith(
              color: tokens.textPrimary,
              fontWeight: AppTextStyles.titleFontWeight,
            ),
            bodyLarge: AppTextStyles.bodyLarge.copyWith(
              color: tokens.textSecondary,
            ),
            bodyMedium: AppTextStyles.body.copyWith(
              color: tokens.textSecondary,
            ),
            bodySmall: AppTextStyles.supporting.copyWith(
              color: tokens.textMuted,
            ),
            labelLarge: AppTextStyles.body.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            labelMedium: AppTextStyles.supporting.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            labelSmall: AppTextStyles.caption.copyWith(
              color: tokens.textMuted,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  // Deprecated properties for backward compatibility during transition
  static Color get background => DS.bg;
  static Color get surfaceDark => DS.surface1;
  static Color get surfaceLight => DS.surface2;
  static Color get surfaceHighlight => DS.surface3;
  static Color get accent => DS.accent;
  static Color get borderLine => DS.borderDefault;
  static Color get borderHover => DS.borderStrong;
  static Color get textPrimary => DS.textPrimary;
  static Color get textSecondary => DS.textSecondary;
  static Color get textMuted => DS.textMuted;

  static ThemeData get theme => themeFor(StreamzTheme.pureBlack);
}

/// Shared near-black backdrop with the app-wide blue top glow.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child, this.topColor});

  final Widget child;
  final Color? topColor;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [AppBackdropSurface(topColor: topColor), child],
  );
}

/// Opaque shared surface for route transitions and the app launch overlay.
class AppBackdropSurface extends StatelessWidget {
  const AppBackdropSurface({super.key, this.topColor});

  final Color? topColor;

  @override
  Widget build(BuildContext context) {
    final color =
        topColor ??
        Theme.of(context).extension<StreamzThemeExtension>()?.scaffoldTopColor ??
        DS.scaffoldGlowColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: DS.scaffoldBackground),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.15),
              radius: 0.9,
              stops: const [0.0, 0.35, 1.0],
              colors: [
                color.withValues(alpha: 0.85),
                color.withValues(alpha: 0.25),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps form and dashboard content readable on wide desktop and TV windows.
class AppContentSliver extends StatelessWidget {
  const AppContentSliver({
    super.key,
    required this.sliver,
    this.maxWidth = DS.contentMaxWidth,
  });

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = width > maxWidth ? (width - maxWidth) / 2 : 0.0;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      sliver: sliver,
    );
  }
}

/// Small, clipped blur surface reused by regular and sliver app bars.
class _AppBarBackdropBlur extends StatefulWidget {
  const _AppBarBackdropBlur();

  @override
  State<_AppBarBackdropBlur> createState() => _AppBarBackdropBlurState();
}

class _AppBarBackdropBlurState extends State<_AppBarBackdropBlur> {
  ScrollNotificationObserverState? _scrollObserver;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollObserver?.removeListener(_handleScrollNotification);
    final isSliverAppBar =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>() !=
        null;
    _scrollObserver = isSliverAppBar
        ? null
        : ScrollNotificationObserver.maybeOf(context);
    _scrollObserver?.addListener(_handleScrollNotification);
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification || notification.depth != 0) {
      return;
    }

    final metrics = notification.metrics;
    final scrolledUnder = switch (metrics.axisDirection) {
      AxisDirection.up => metrics.extentAfter > 0,
      AxisDirection.down => metrics.extentBefore > 0,
      AxisDirection.left || AxisDirection.right => null,
    };
    if (scrolledUnder != null && scrolledUnder != _scrolledUnder) {
      setState(() => _scrolledUnder = scrolledUnder);
    }
  }

  @override
  void dispose() {
    _scrollObserver?.removeListener(_handleScrollNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<
      FlexibleSpaceBarSettings
    >();
    final scrolledUnder = settings?.isScrolledUnder ?? _scrolledUnder;
    if (!scrolledUnder) return const SizedBox.expand();

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: ColoredBox(
          color: context.tokens.background.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

/// Shared transparent app bar for every scrolling page. Keep page titles,
/// navigation actions, and per-screen scrolling behavior in the callers.
class AppSliverAppBar extends StatelessWidget {
  const AppSliverAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.floating = false,
    this.pinned = false,
    this.snap = false,
    this.stretch = false,
    this.primary = true,
    this.forceElevated = false,
    this.toolbarHeight,
    this.collapsedHeight,
    this.expandedHeight,
    this.leadingWidth,
    this.titleSpacing = 0,
    this.flexibleSpace,
    this.actionsPadding,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;
  final bool floating;
  final bool pinned;
  final bool snap;
  final bool stretch;
  final bool primary;
  final bool forceElevated;
  final double? toolbarHeight;
  final double? collapsedHeight;
  final double? expandedHeight;
  final double? leadingWidth;
  final double titleSpacing;
  final Widget? flexibleSpace;
  final EdgeInsetsGeometry? actionsPadding;

  @override
  Widget build(BuildContext context) => SliverAppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    forceMaterialTransparency: true,
    title: title,
    leading: leading,
    actions: actions,
    bottom: bottom,
    automaticallyImplyLeading: automaticallyImplyLeading,
    centerTitle: centerTitle ?? true,
    floating: floating,
    pinned: pinned,
    snap: snap,
    stretch: stretch,
    primary: primary,
    forceElevated: forceElevated,
    toolbarHeight: toolbarHeight ?? kToolbarHeight,
    collapsedHeight: collapsedHeight,
    expandedHeight: expandedHeight,
    leadingWidth: leadingWidth,
    titleSpacing: titleSpacing,
    flexibleSpace: Stack(
      fit: StackFit.expand,
      children: [
        ?flexibleSpace,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height:
              (primary ? MediaQuery.paddingOf(context).top : 0) +
              (toolbarHeight ?? kToolbarHeight),
          child: const _AppBarBackdropBlur(),
        ),
      ],
    ),
    actionsPadding: actionsPadding,
  );
}

extension ThemeUtils on BuildContext {
  StreamzThemeExtension get tokens =>
      Theme.of(this).extension<StreamzThemeExtension>()!;
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}

// ─────────────────────────────────────────────────────────────────────────────
// TV FOCUS HELPERS
// ─────────────────────────────────────────────────────────────────────────────

KeyEventResult handleTVSelectKey(KeyEvent event, VoidCallback? onTap) {
  if (onTap != null &&
      event is KeyDownEvent &&
      (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
    onTap();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// FIX: Wraps Scrollable.ensureVisible in addPostFrameCallback to prevent
/// \"context does not contain a Scrollable\" crash on frame 1.
void handleTVFocusScroll(bool hasFocus, BuildContext context) {
  if (!hasFocus) return;
  // Defer until after the current frame's layout so the widget is fully
  // attached to its scroll ancestor before we request scroll.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Guard: context may have been unmounted by the time the callback fires.
    if (!context.mounted) return;
    try {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // No ancestor Scrollable — safe to ignore (e.g. full-screen TV cards).
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CORE UI COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset,
  });
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: extendBody,
    extendBodyBehindAppBar: extendBodyBehindAppBar,
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    backgroundColor: Colors.transparent,
    appBar: appBar == null ? null : AppBlurredAppBar(child: appBar!),
    body: body,
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: floatingActionButtonLocation,
    bottomNavigationBar: bottomNavigationBar,
  );
}

/// Adds a restrained backdrop blur behind transparent app bars so content
/// scrolling beneath remains visible without competing with the title/actions.
class AppBlurredAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppBlurredAppBar({super.key, required this.child});

  final PreferredSizeWidget child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const _AppBarBackdropBlur(),
      child,
    ],
  );
}

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onFocusChanged,
    this.focusNode,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onFocusChanged;
  final FocusNode? focusNode;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final active = _isFocused || _isHovered;
    final interactive = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: interactive,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: active
              ? tokens.surface3
              : tokens.surface1.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(
            color: _isFocused
                ? tokens.focusColor
                : _isHovered
                ? tokens.borderStrong
                : tokens.border.withValues(alpha: 0.55),
            width: _isFocused ? DS.focusWidth : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            focusNode: widget.focusNode,
            canRequestFocus: interactive,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onFocusChange: (value) {
              setState(() => _isFocused = value);
              widget.onFocusChanged?.call(value);
              handleTVFocusScroll(value, context);
            },
            onHover: (value) => setState(() => _isHovered = value),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    required this.padding,
    this.color,
    this.borderColor,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? context.tokens.surface2.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(DS.radius(18)),
      border: Border.all(
        color: borderColor ?? context.tokens.border.withValues(alpha: 0.55),
        width: 1,
      ),
    ),
    child: child,
  );
}

/// Compact variant of the same accessible button used throughout the app.
class CompactBtn extends StatelessWidget {
  const CompactBtn({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.isPrimary = true,
    this.isLoading = false,
    this.height = 48,
  });
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) => AppButton(
    label: label,
    icon: icon,
    onTap: onTap,
    isPrimary: isPrimary,
    isLoading: isLoading,
    height: height,
  );
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.isPrimary = true,
    this.isLoading = false,
    this.height = 54,
  });
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: DS.s12),
        ] else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: DS.s12),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(48, height < 48 ? 48 : height)),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? context.tokens.focusColor
              : context.tokens.border,
          width: states.contains(WidgetState.focused) ? 3 : 1,
        ),
      ),
    );
    return Semantics(
      liveRegion: isLoading,
      child: SizedBox(
        width: double.infinity,
        child: isPrimary
            ? ElevatedButton(
                onPressed: isLoading ? null : onTap,
                style: style,
                child: content,
              )
            : OutlinedButton(
                onPressed: isLoading ? null : onTap,
                style: style,
                child: content,
              ),
      ),
    );
  }
}

/// Focusable, touch friendly action grid shared by gateway and server screens.
class AppActionGrid extends StatelessWidget {
  const AppActionGrid({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(DS.s16),
    this.spacing = DS.s12,
    this.minTileWidth = 140,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double minTileWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final resolvedPadding = padding.resolve(Directionality.of(context));
      final availableWidth = constraints.maxWidth - resolvedPadding.horizontal;
      final columns = constraints.hasBoundedWidth
          ? DS.responsiveColumns(
              context,
              availableWidth: availableWidth,
              spacing: spacing,
              minTileWidth: minTileWidth,
              maxColumns: maxColumns,
            )
          : maxColumns;
      final scaledFont = MediaQuery.textScalerOf(context).scale(14);
      final tileHeight = (84 + scaledFont * 2.5).clamp(120.0, 176.0);
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        mainAxisExtent: tileHeight,
        children: children,
      );
    },
  );
}

class AppActionCard extends StatelessWidget {
  const AppActionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.statusLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: statusLabel == null ? null : isActive,
    child: AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s12,
          vertical: DS.s16,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive
                  ? context.tokens.success
                  : context.tokens.textPrimary,
            ),
            SizedBox(height: statusLabel == null ? DS.s12 : DS.s8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
            if (statusLabel != null) ...[
              const SizedBox(height: DS.s4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.circle_outlined,
                    size: 13,
                    color: isActive
                        ? context.tokens.textPrimary
                        : context.tokens.textMuted,
                  ),
                  const SizedBox(width: DS.s4),
                  Flexible(
                    child: Text(
                      statusLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: isActive
                            ? context.tokens.textPrimary
                            : context.tokens.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.isActive = false,
    this.activeColor,
    this.activeFg,
  });
  final String label;
  final bool isActive;
  final Color? activeColor;
  final Color? activeFg;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: isActive ? (activeColor ?? tokens.accent) : tokens.surface3,
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.style(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: isActive
              ? (activeFg ?? tokens.background)
              : tokens.textSecondary,
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.tokens.surface3,
      border: Border.all(color: context.tokens.border),
    ),
  );
}

class NetworkImageFade extends StatelessWidget {
  const NetworkImageFade({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallbackIcon = LucideIcons.film,
  });
  final String url;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      int? decodeDimension(double logicalSize) {
        if (!logicalSize.isFinite || logicalSize <= 0) return null;
        return (logicalSize * pixelRatio).ceil().clamp(1, 4096).toInt();
      }
      final useWidth = constraints.maxWidth.isFinite &&
          (!constraints.maxHeight.isFinite ||
              constraints.maxWidth >= constraints.maxHeight);
      final decodeSize = decodeDimension(
        useWidth ? constraints.maxWidth : constraints.maxHeight,
      );

      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        // Set one dimension so the decoded image retains its source aspect
        // ratio while staying close to the rendered pixel size.
        memCacheWidth: useWidth ? decodeSize : null,
        memCacheHeight: useWidth ? null : decodeSize,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (_, _) => Container(
          color: context.tokens.surface1,
          child: Center(
            child: Icon(fallbackIcon, color: context.tokens.textMuted, size: 32),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          color: context.tokens.surface1,
          child: Center(
            child: Icon(fallbackIcon, color: context.tokens.textMuted, size: 32),
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAYER COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({
    super.key,
    required this.player,
    this.compact = false,
    this.isReadOnly = false,
  });
  final Player player;
  final bool compact;
  final bool isReadOnly;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  bool _isFocused = false;

  String _fmt(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return '${d.inHours}:'
          '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
          '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.toString().padLeft(2, '0')}:'
        '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (_, posSnap) => StreamBuilder<Duration>(
        stream: widget.player.stream.duration,
        builder: (_, durSnap) {
          final pos = posSnap.data ?? Duration.zero;
          final dur = durSnap.data ?? Duration.zero;
          final maxVal = dur.inMilliseconds.toDouble().clamp(
            1.0,
            double.infinity,
          );
          final curVal = pos.inMilliseconds.toDouble().clamp(0.0, maxVal);

          return Focus(
            onFocusChange: (val) => setState(() => _isFocused = val),
            onKeyEvent: (node, event) {
              if (widget.isReadOnly) return KeyEventResult.ignored;
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }

              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                widget.player.seek(pos - const Duration(seconds: 10));
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                widget.player.seek(pos + const Duration(seconds: 10));
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: _isFocused
                    ? tokens.surface3.withValues(alpha: 0.24)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(
                  color: _isFocused
                      ? tokens.focusColor.withValues(alpha: 0.8)
                      : Colors.transparent,
                  width: _isFocused ? DS.focusWidth : 1,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: tokens.focusShadow.withValues(alpha: 0.14),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: widget.compact ? 56 : 80,
                    child: Text(
                      _fmt(pos.inSeconds),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: widget.compact ? 12 : 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s16),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: widget.compact ? 4 : 6,
                        activeTrackColor: widget.isReadOnly
                            ? tokens.warning
                            : tokens.accent,
                        inactiveTrackColor: tokens.surface3,
                        thumbColor: widget.isReadOnly
                            ? Colors.transparent
                            : tokens.accent,
                        overlayShape: SliderComponentShape.noOverlay,
                        trackShape: const RoundedRectSliderTrackShape(),
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: widget.isReadOnly ? 0 : 7,
                        ),
                      ),
                      child: Slider(
                        value: curVal,
                        min: 0,
                        max: maxVal,
                        onChanged: widget.isReadOnly
                            ? null
                            : (v) => widget.player.seek(
                                Duration(milliseconds: v.toInt()),
                              ),
                        semanticFormatterCallback: (value) =>
                            '${_fmt((value / 1000).round())} of ${_fmt(dur.inSeconds)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s16),
                  SizedBox(
                    width: widget.compact ? 56 : 80,
                    child: Text(
                      widget.isReadOnly ? 'LIVE' : _fmt(dur.inSeconds),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: widget.isReadOnly
                            ? tokens.warning
                            : tokens.textMuted,
                        fontSize: widget.compact ? 12 : 16,
                        fontWeight: widget.isReadOnly
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
