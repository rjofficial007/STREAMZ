// presentation/home/permission_screen.dart
// ============================================================================
// STREAMZ — Permission Setup Screen
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../server/server_dashboard.dart';
import '../server/server_viewmodel.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _photos = false;
  bool _audio = false;
  bool _background = false;

  Future<void> _requestPhotos() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux) {
      if (mounted) setState(() => _photos = true);
      return;
    }
    final ps = await PhotoManager.requestPermissionExtend();
    if (mounted) setState(() => _photos = ps.isAuth);
  }

  Future<void> _requestAudio() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux) {
      if (mounted) setState(() => _audio = true);
      return;
    }
    final ok = await OnAudioQuery().checkAndRequest(retryRequest: true);
    if (mounted) setState(() => _audio = ok);
  }

  Future<void> _requestBackground() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        const config = FlutterBackgroundAndroidConfig(
          notificationTitle: 'Streamz Server',
          notificationText: 'Background service active.',
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        );
        final ok = await FlutterBackground.initialize(androidConfig: config);
        if (ok && mounted) setState(() => _background = true);
      } catch (e) {
        debugPrint('Background permission error: $e');
      }
    } else {
      if (mounted) setState(() => _background = true);
    }
  }

  Future<void> _proceed() async {
    if (!_photos) {
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

  @override
  Widget build(BuildContext context) {
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
            child: IconButton(icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 20), onPressed: () => Navigator.pop(context)),
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
                    // Header
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
                                    fontStyle: FontStyle.normal,
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

                    // Permission tiles
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
                                  subtitle: (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ? 'AUTO-GRANTED ON WINDOWS' : 'REQUIRED FOR VIDEO SCANNING',
                                  icon: PhosphorIconsFill.folderOpen,
                                  isGranted: _photos,
                                  isMobile: isMobile,
                                  autoFocus: true,
                                  onTap: _requestPhotos,
                                ),
                                const SizedBox(height: DS.s12),
                                _PermissionTile(
                                  title: 'AUDIO ENGINE',
                                  subtitle: (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ? 'AUTO-GRANTED ON WINDOWS' : 'REQUIRED FOR MUSIC BROADCASTS',
                                  icon: PhosphorIconsFill.musicNote,
                                  isGranted: _audio,
                                  isMobile: isMobile,
                                  onTap: _requestAudio,
                                ),
                                const SizedBox(height: DS.s12),
                                _PermissionTile(
                                  title: 'PERSISTENCE',
                                  subtitle: (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ? 'STAY ACTIVE IN BACKGROUND' : 'MANAGED BY SYSTEM',
                                  icon: PhosphorIconsFill.lightning,
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

                    // CTA
                    Padding(
                      padding: EdgeInsets.all(hPad),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: AppButton(label: 'INITIALIZE BROADCAST ENGINE', isPrimary: _photos, height: isMobile ? 54 : 64, onTap: _proceed),
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
                // Toggle indicator
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
