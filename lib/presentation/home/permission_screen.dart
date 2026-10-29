// presentation/home/permission_screen.dart
// ============================================================================
// STREAMZ — Permission Setup Screen (Samsung-Style)
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';

/// True when this platform needs no runtime permissions.
bool get _isAutoGrantPlatform =>
    kIsWeb ||
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _photos = false;
  bool _audio = false;
  bool _background = false;
  bool _proceeding = false;

  @override
  void initState() {
    super.initState();
    if (_isAutoGrantPlatform) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _autoGrantAndProceed(),
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkCurrentState());
    }
  }

  Future<void> _checkCurrentState() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (FlutterBackground.isBackgroundExecutionEnabled) {
          if (mounted) setState(() => _background = true);
        }
      } catch (_) {}
    } else {
      if (mounted) setState(() => _background = true);
    }
  }

  Future<void> _autoGrantAndProceed() async {
    if (!mounted) return;
    setState(() {
      _photos = true;
      _audio = true;
      _background = true;
    });
    await _proceed();
  }

  // ── Permission Requests ──────────────────────────────────────────────────

  Future<void> _requestPhotos() async {
    if (_isAutoGrantPlatform) {
      setState(() => _photos = true);
      return;
    }
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (mounted) {
        setState(() => _photos = ps.isAuth);
        if (!ps.isAuth) _showDeniedSnack('STORAGE', 'VIDEO & PHOTO SCANNING');
      }
    } catch (e) {
      debugPrint('[Permission] Photo error: $e');
    }
  }

  Future<void> _requestAudio() async {
    if (_isAutoGrantPlatform) {
      setState(() => _audio = true);
      return;
    }
    try {
      final ok = await OnAudioQuery().checkAndRequest(retryRequest: true);
      if (mounted) {
        setState(() => _audio = ok);
        if (!ok) _showDeniedSnack('AUDIO', 'MUSIC BROADCASTS');
      }
    } catch (e) {
      debugPrint('[Permission] Audio error: $e');
    }
  }

  Future<void> _requestBackground() async {
    if (_isAutoGrantPlatform) {
      setState(() => _background = true);
      return;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        const config = FlutterBackgroundAndroidConfig(
          notificationTitle: 'VOIDCAST — Uplink Active',
          notificationText: 'Broadcasting on local network.',
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
          enableWifiLock: true,
        );
        final ok = await FlutterBackground.initialize(androidConfig: config);
        if (mounted) setState(() => _background = ok);
      } catch (e) {
        debugPrint('[Permission] Background error: $e');
        if (mounted) setState(() => _background = true);
      }
    } else {
      setState(() => _background = true);
    }
  }

  void _showDeniedSnack(String permission, String feature) {
    if (!mounted) return;
    final tokens = context.tokens;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$permission ACCESS DENIED. OPEN DEVICE SETTINGS TO ENABLE $feature.',
          style: AppTextStyles.caption.copyWith(
            color: tokens.background,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: tokens.textPrimary,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radius(12))),
      ),
    );
  }

  // ── Proceed ───────────────────────────────────────────────────────────────

  Future<void> _proceed() async {
    if (_proceeding) return;
    final tokens = context.tokens;

    if (!_photos && !_isAutoGrantPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'MEDIA STORAGE ACCESS IS MANDATORY.',
            style: AppTextStyles.caption.copyWith(
              color: tokens.background,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: tokens.textPrimary,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radius(12)),
          ),
        ),
      );
      return;
    }

    setState(() => _proceeding = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_granted', true);

    if (!mounted) return;

    context.pushReplacement('/server');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (_isAutoGrantPlatform) {
      return AppScaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: tokens.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final isMobile = DS.isMobile(context);

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppSliverAppBar(isMobile),
            AppContentSliver(sliver: _buildBody(isMobile)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSliverAppBar(bool isMobile) {
    final tokens = context.tokens;
    return AppSliverAppBar(
      floating: true,
      pinned: true,
      titleSpacing: 0,
      leading: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              context.pop();
              return null;
            },
          ),
        },
        child: Focus(
          onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => context.pop()),
          child: AppBackButton(onPressed: () => context.pop()),
        ),
      ),
      title: Text(
        'Permissions',
        style: AppTextStyles.style(
          color: tokens.textPrimary,
          fontSize: isMobile ? 20 : 24,
          fontWeight: AppTextStyles.titleFontWeight,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildBody(bool isMobile) {
    final tokens = context.tokens;
    return SliverList(
      delegate: SliverChildListDelegate([
        _AuthAnalysisCard(
          isMobile: isMobile,
          photos: _photos,
          audio: _audio,
          background: _background,
        ),

        AppActionGrid(
          padding: const EdgeInsets.all(16),
          children: [
            AppActionCard(
              label: 'Photos & video',
              icon: LucideIcons.folderOpen,
              isActive: _photos,
              onTap: _requestPhotos,
            ),
            AppActionCard(
              label: 'Audio',
              icon: LucideIcons.music,
              isActive: _audio,
              onTap: _requestAudio,
            ),
            AppActionCard(
              label: 'Background',
              icon: LucideIcons.zap,
              isActive: _background,
              onTap: _requestBackground,
            ),
          ],
        ),

        Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ArchitectureTile(
                title: 'Media library',
                subtitle: 'Allow access to scan videos and photos',
                icon: LucideIcons.database,
                isFirst: true,
              ),
              const _ArchitectureTile(
                title: 'Music library',
                subtitle: 'Allow access to scan audio',
                icon: LucideIcons.activity,
              ),
              const _ArchitectureTile(
                title: 'Background activity',
                subtitle: 'Keep sharing active while the app is minimized',
                icon: LucideIcons.cpu,
              ),

              GestureDetector(
                onTap: _proceed,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: _photos ? tokens.surface3 : tokens.surface2,
                    borderRadius: BorderRadius.circular(DS.radius(16)),
                    border: Border.all(
                      color: _photos
                          ? tokens.focusColor.withValues(alpha: 0.85)
                          : tokens.border.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Center(
                    child: _proceeding
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: tokens.background,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Continue',
                            style: AppTextStyles.style(
                              color: _photos
                                  ? tokens.background
                                  : tokens.textMuted,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 100),
      ]),
    );
  }
}

class _AuthAnalysisCard extends StatelessWidget {
  const _AuthAnalysisCard({
    required this.isMobile,
    required this.photos,
    required this.audio,
    required this.background,
  });
  final bool isMobile;
  final bool photos;
  final bool audio;
  final bool background;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    var granted = 0;
    if (photos) granted++;
    if (audio) granted++;
    if (background) granted++;
    final progress = granted / 3;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DS.radius(20)),
        border: Border.all(color: tokens.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Permissions overview',
                style: AppTextStyles.titleLarge.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: AppTextStyles.titleFontWeight,
                ),
              ),
              _BlinkingDot(isOnline: photos),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MANDATORY AUTH',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      photos ? 'GRANTED' : 'REQUIRED',
                      style: AppTextStyles.body.copyWith(
                        color: photos ? tokens.success : tokens.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL MODULES',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$granted / 3',
                      style: AppTextStyles.body.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),
          Stack(
            children: [
              Container(height: 8, color: tokens.surface2),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.01, 1.0),
                child: Container(height: 8, color: tokens.accent),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Expanded(
                child: _legend(
                  context,
                  'CORE',
                  photos ? 'READY' : 'WAITING',
                  tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _legend(
                  context,
                  'EXTENSIONS',
                  audio ? 'ACTIVE' : 'OPTIONAL',
                  tokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final tokens = context.tokens;
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: tokens.textMuted),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ArchitectureTile extends StatefulWidget {
  const _ArchitectureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isFirst = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isFirst;

  @override
  State<_ArchitectureTile> createState() => _ArchitectureTileState();
}

class _ArchitectureTileState extends State<_ArchitectureTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Focus(
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) handleTVFocusScroll(v, context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _focused
              ? tokens.textPrimary.withValues(alpha: 0.05)
              : tokens.surface1,
          border: Border(
            bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)),
            top: widget.isFirst
                ? BorderSide(color: tokens.border.withValues(alpha: 0.15))
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.surface2,
                border: Border.all(
                  color: _focused
                      ? tokens.textPrimary
                      : tokens.border.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                widget.icon,
                color: _focused ? tokens.textPrimary : tokens.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: AppTextStyles.title.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: AppTextStyles.titleFontWeight,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: tokens.textMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            if (_focused)
              Icon(
                LucideIcons.chevronRight,
                color: tokens.textPrimary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({required this.isOnline});
  final bool isOnline;

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (!widget.isOnline) {
      return Container(width: 8, height: 8, color: tokens.textDisabled);
    }
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: tokens.success,
          boxShadow: [BoxShadow(color: tokens.success, blurRadius: 4)],
        ),
      ),
    );
  }
}
