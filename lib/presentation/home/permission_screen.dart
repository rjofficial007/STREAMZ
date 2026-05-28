// presentation/home/permission_screen.dart
// ============================================================================
// STREAMZ — Permission Setup Screen (Production-Fixed)
//
// BUGS FIXED:
//   1. On desktop/web, permissions were never auto-granted before _proceed()
//      was called, so _photos stayed false and the mandatory-check snackbar
//      blocked navigation even though no real permission is needed.
//      Fixed: auto-grant all permissions on desktop/web immediately in initState.
//   2. The screen showed even on platforms that need no permissions at all
//      (Windows, macOS, Linux, Web) because role_selection_screen only checked
//      a SharedPreferences flag, not the platform. Fixed by auto-proceeding.
//   3. No feedback when permission was denied — user tapped GRANT, nothing
//      happened, and the tile stayed red. Added denied-state handling with
//      an explanatory snack.
//   4. Removed aggressive auto-prompting on screen load. Permissions are now
//      STRICTLY requested only when the user taps the specific tile.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../server/server_dashboard.dart';
import '../server/server_viewmodel.dart';

/// True when this platform needs no runtime permissions (everything is
/// governed by OS-level user account permissions).
bool get _isAutoGrantPlatform =>
    kIsWeb || (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux));

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoGrantAndProceed());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkCurrentState());
    }
  }

  Future<void> _checkCurrentState() async {
    // PASSIVE CHECKS ONLY.
    // We intentionally do NOT call requestPermissionExtend() or checkAndRequest() here
    // to prevent unwanted system dialogs popping up when the screen first loads.

    // Background execution check is passive and does not prompt the user.
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

  // ── Permission Requests (Triggered ONLY on Tap) ───────────────────────────

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
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWifiLock: true,
        );
        final ok = await FlutterBackground.initialize(androidConfig: config);
        if (mounted) setState(() => _background = ok);
      } catch (e) {
        debugPrint('[Permission] Background error: $e');
        // Background is optional — allow proceed without it.
        if (mounted) setState(() => _background = true);
      }
    } else {
      setState(() => _background = true);
    }
  }

  void _showDeniedSnack(String permission, String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$permission ACCESS DENIED. OPEN DEVICE SETTINGS TO ENABLE $feature.', style: AppTheme.theme.textTheme.labelMedium?.copyWith(color: Colors.black)),
        backgroundColor: DS.accent,
        duration: const Duration(seconds: 4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  // ── Proceed ───────────────────────────────────────────────────────────────

  Future<void> _proceed() async {
    if (_proceeding) return;

    if (!_photos && !_isAutoGrantPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('MEDIA STORAGE ACCESS IS MANDATORY.', style: AppTheme.theme.textTheme.labelMedium?.copyWith(color: Colors.black)),
          backgroundColor: DS.accent,
          duration: const Duration(seconds: 3),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      );
      return;
    }

    setState(() => _proceeding = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_granted', true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(create: (_) => ServerViewModel(), child: const ServerDashboard()),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isAutoGrantPlatform) {
      return const Scaffold(
        backgroundColor: DS.bg,
        body: Center(child: CircularProgressIndicator(color: DS.accent, strokeWidth: 2)),
      );
    }

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: DS.bg,
        leading: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                Navigator.pop(context);
                return null;
              },
            ),
          },
          child: Focus(
            onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => Navigator.pop(context)),
            child: IconButton(icon: const Icon(LucideIcons.arrowLeft, size: 20), onPressed: () => Navigator.pop(context)),
          ),
        ),
        title: Text('AUTHORIZATION', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(opacity: 0.10, child: const CustomPaint(painter: GridPainter())),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isDesktop = width > DS.bpTablet;
                final isMobile = width <= DS.bpMobile;
                final hPad = DS.hPad(width);
                final vPad = isMobile ? 24.0 : 60.0;

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text('MEDIA', style: AppTheme.theme.textTheme.displayLarge?.copyWith(fontSize: isDesktop ? 100 : 72)),
                                const SizedBox(width: 20),
                                Text(
                                  'SETUP',
                                  style: AppTheme.theme.textTheme.displayLarge?.copyWith(
                                    fontSize: isDesktop ? 100 : 72,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = isMobile ? 1.5 : 2.5
                                      ..color = DS.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DS.s12),
                          Text(
                            'GRANT PERMISSIONS TO INDEX YOUR LOCAL BROADCAST LIBRARY.',
                            style: AppTheme.theme.textTheme.bodyLarge?.copyWith(fontSize: isMobile ? 13 : 16, color: DS.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isMobile ? 20 : 28),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(horizontal: hPad),
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                _PermissionTile(
                                  title: 'FILESYSTEM',
                                  subtitle: 'REQUIRED FOR VIDEO SCANNING',
                                  icon: LucideIcons.folderOpen,
                                  isGranted: _photos,
                                  isMobile: isMobile,
                                  autoFocus: true,
                                  onTap: _requestPhotos,
                                ),
                                const SizedBox(height: DS.s12),
                                _PermissionTile(title: 'AUDIO ENGINE', subtitle: 'REQUIRED FOR MUSIC BROADCASTS', icon: LucideIcons.music, isGranted: _audio, isMobile: isMobile, onTap: _requestAudio),
                                const SizedBox(height: DS.s12),
                                _PermissionTile(
                                  title: 'PERSISTENCE',
                                  subtitle: defaultTargetPlatform == TargetPlatform.android ? 'STAY ACTIVE IN BACKGROUND' : 'MANAGED BY SYSTEM',
                                  icon: LucideIcons.zap,
                                  isGranted: _background,
                                  isMobile: isMobile,
                                  onTap: _requestBackground,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(hPad),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: AppButton(
                            label: _proceeding ? 'INITIALIZING...' : 'INITIALIZE BROADCAST ENGINE',
                            isPrimary: _photos,
                            isLoading: _proceeding,
                            height: isMobile ? 54 : 64,
                            onTap: _proceed,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERMISSION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isGranted;
  final bool isMobile;
  final VoidCallback onTap;
  final bool autoFocus;

  const _PermissionTile({required this.title, required this.subtitle, required this.icon, required this.isGranted, required this.isMobile, required this.onTap, this.autoFocus = false});

  @override
  State<_PermissionTile> createState() => _PermissionTileState();
}

class _PermissionTileState extends State<_PermissionTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Focus(
        autofocus: widget.autoFocus,
        onFocusChange: (v) {
          setState(() => _isFocused = v);
          handleTVFocusScroll(v, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.all(widget.isMobile ? 20 : 28),
            decoration: BoxDecoration(
              color: _isFocused ? DS.surface3 : DS.surface1,
              border: Border.all(color: widget.isGranted ? DS.accent : (_isFocused ? Colors.white : DS.borderDefault), width: (widget.isGranted || _isFocused) ? 2.0 : 1.0),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.isGranted ? DS.accent : DS.textSecondary, size: widget.isMobile ? 24 : 32),
                SizedBox(width: widget.isMobile ? 16 : 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: AppTheme.theme.textTheme.headlineSmall?.copyWith(fontSize: widget.isMobile ? 18 : 22, height: 1.0)),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: widget.isMobile ? 10 : 11, color: DS.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DS.s16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: widget.isMobile ? 40 : 48,
                  height: widget.isMobile ? 20 : 24,
                  decoration: BoxDecoration(
                    color: widget.isGranted ? DS.accent : Colors.transparent,
                    border: Border.all(color: widget.isGranted ? DS.accent : DS.textMuted, width: 2),
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: widget.isGranted ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: widget.isMobile ? 12 : 16,
                          height: widget.isMobile ? 12 : 16,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: widget.isGranted ? DS.bg : DS.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
