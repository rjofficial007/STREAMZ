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
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_summary_components.dart';

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
        if (!ps.isAuth) _showDeniedSnack('Storage', 'video and photo scanning');
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
        if (!ok) _showDeniedSnack('Audio', 'music broadcasts');
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
          notificationTitle: '${AppStrings.appTitle} is active',
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
          '$permission access was denied. Open device settings to enable $feature.',
          style: AppTextStyles.caption.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: tokens.surface3,
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
            'Allow media access to continue.',
            style: AppTextStyles.caption.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: tokens.surface3,
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
    return SliverList(
      delegate: SliverChildListDelegate([
        _PermissionSummaryCard(
          isMobile: isMobile,
          photos: _photos,
          audio: _audio,
          background: _background,
        ),

        AppActionGrid(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          spacing: 8,
          minTileWidth: 80,
          maxColumns: 3,
          children: [
            AppActionCard(
              label: 'Photos & video',
              icon: LucideIcons.folderOpen,
              isActive: _photos,
              statusLabel: _photos ? 'Granted' : 'Required',
              onTap: _requestPhotos,
            ),
            AppActionCard(
              label: 'Audio',
              icon: LucideIcons.music,
              isActive: _audio,
              statusLabel: _audio ? 'Enabled' : 'Optional',
              onTap: _requestAudio,
            ),
            AppActionCard(
              label: 'Background',
              icon: LucideIcons.zap,
              isActive: _background,
              statusLabel: _background ? 'Enabled' : 'Optional',
              onTap: _requestBackground,
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: 'Continue',
                onTap: _proceed,
                isPrimary: _photos,
                isLoading: _proceeding,
                height: 56,
              ),
            ],
          ),
        ),

        const SizedBox(height: DS.s24),
      ]),
    );
  }
}

class _PermissionSummaryCard extends StatelessWidget {
  const _PermissionSummaryCard({
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
          AppSummaryHeader(
            title: 'Device access',
            titleStyle: AppTextStyles.titleLarge.copyWith(
              color: tokens.textPrimary,
              fontWeight: AppTextStyles.titleFontWeight,
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DS.s12,
                vertical: DS.s8,
              ),
              decoration: BoxDecoration(
                color: (photos ? tokens.success : tokens.warning).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(DS.radius(99)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    photos
                        ? LucideIcons.circleCheck
                        : LucideIcons.circleAlert,
                    size: 16,
                    color: photos ? tokens.success : tokens.warning,
                  ),
                  const SizedBox(width: DS.s8),
                  Flexible(
                    child: Text(
                      photos ? 'Ready' : 'Permission needed',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Media access',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      photos ? 'Granted' : 'Required',
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
                      'Permissions complete',
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
                child: AppSummaryLegend(
                  label: 'Media library',
                  value: photos ? 'Ready' : 'Waiting',
                  markerColor: tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppSummaryLegend(
                  label: 'Audio access',
                  value: audio ? 'Enabled' : 'Optional',
                  markerColor: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

