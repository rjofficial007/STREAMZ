// presentation/home/permission_screen.dart
// ============================================================================
// STREAMZ — Permission Setup Screen (Samsung-Style)
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../server/server_dashboard.dart';
import '../server/server_viewmodel.dart';

// --- Web UI Color Palette & Styles (Synced with System Dashboards) ---
const Color kWebBlack = Color(0xFF000000);
const Color kWebSurface = Color(0xFF0A0A0A);
const Color kWebSurface2 = Color(0xFF111111);
const Color kWebWhite = Color(0xFFFFFFFF);
final Color kWebBorder = Colors.white.withValues(alpha: 0.15);
final Color kWebTextMuted = Colors.white.withValues(alpha: 0.3);
final Color kWebText = Colors.white.withValues(alpha: 0.6);

/// True when this platform needs no runtime permissions.
bool get _isAutoGrantPlatform =>
    kIsWeb || (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux);

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
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$permission ACCESS DENIED. OPEN DEVICE SETTINGS TO ENABLE $feature.', style: GoogleFonts.dmMono(color: kWebBlack, fontWeight: FontWeight.bold, fontSize: 11)),
        backgroundColor: kWebWhite,
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
          content: Text('MEDIA STORAGE ACCESS IS MANDATORY.', style: GoogleFonts.dmMono(color: kWebBlack, fontWeight: FontWeight.bold, fontSize: 11)),
          backgroundColor: kWebWhite,
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

  @override
  Widget build(BuildContext context) {
    if (_isAutoGrantPlatform) {
      return const Scaffold(
        backgroundColor: kWebBlack,
        body: Center(child: CircularProgressIndicator(color: kWebWhite, strokeWidth: 2)),
      );
    }

    final isMobile = DS.isMobile(context);

    return Scaffold(
      backgroundColor: kWebBlack,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(isMobile),
            _buildBody(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isMobile) {
    return SliverAppBar(
      backgroundColor: kWebSurface,
      floating: true,
      elevation: 0,
      pinned: true,
      titleSpacing: 0,
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
          child: IconButton(
            icon: Icon(LucideIcons.chevronLeft, size: 20, color: kWebWhite),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: Text(
        'AUTHORIZATION',
        style: GoogleFonts.barlowCondensed(
          color: kWebWhite, 
          fontSize: isMobile ? 20 : 24, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 4
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kWebBorder, height: 1),
      ),
    );
  }

  Widget _buildBody(bool isMobile) {
    return SliverList(
      delegate: SliverChildListDelegate([
        _AuthAnalysisCard(isMobile: isMobile, photos: _photos, audio: _audio, background: _background),
        
        Container(
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)), 
            color: kWebBorder
          ),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            children: [
              _QuickActionCard(
                label: 'FILESYSTEM',
                icon: LucideIcons.folderOpen,
                isActive: _photos,
                onTap: _requestPhotos,
              ),
              _QuickActionCard(
                label: 'AUDIO',
                icon: LucideIcons.music,
                isActive: _audio,
                onTap: _requestAudio,
              ),
              _QuickActionCard(
                label: 'PERSISTENCE',
                icon: LucideIcons.zap,
                isActive: _background,
                onTap: _requestBackground,
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               _ArchitectureTile(
                title: 'STORAGE PERMISSION',
                subtitle: 'REQUIRED FOR MEDIA INDEXING',
                icon: LucideIcons.database,
                isFirst: true,
              ),
              _ArchitectureTile(
                title: 'AUDIO ENGINE',
                subtitle: 'REQUIRED FOR MUSIC STREAMING',
                icon: LucideIcons.activity,
              ),
              _ArchitectureTile(
                title: 'BACKGROUND MODULE',
                subtitle: 'KEEP BROADCAST ENGINE ACTIVE',
                icon: LucideIcons.cpu,
              ),


              GestureDetector(
                onTap: _proceed,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: _photos ? kWebWhite : kWebSurface2,
                    border: Border.all(color: _photos ? kWebWhite : kWebBorder),
                  ),
                  child: Center(
                    child: _proceeding 
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kWebBlack, strokeWidth: 2))
                      : Text(
                        'INITIALIZE BROADCAST ENGINE', 
                        style: GoogleFonts.dmMono(
                          color: _photos ? kWebBlack : kWebTextMuted, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 2,
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
  final bool isMobile;
  final bool photos;
  final bool audio;
  final bool background;
  
  const _AuthAnalysisCard({required this.isMobile, required this.photos, required this.audio, required this.background});

  @override
  Widget build(BuildContext context) {
    int granted = 0;
    if (photos) granted++;
    if (audio) granted++;
    if (background) granted++;
    final progress = granted / 3;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: kWebSurface,
        border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AUTHORIZATION ANALYSIS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                    Text('MANDATORY AUTH', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(photos ? 'GRANTED' : 'REQUIRED', style: GoogleFonts.dmMono(color: photos ? DS.success : Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('TOTAL MODULES', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('$granted / 3', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),
          Stack(
            children: [
              Container(height: 8, color: kWebSurface2),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.01, 1.0), 
                child: Container(height: 8, color: kWebWhite),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Expanded(child: _legend('CORE', photos ? 'READY' : 'WAITING', kWebWhite)),
              const SizedBox(width: 16),
              Expanded(child: _legend('EXTENSIONS', audio ? 'ACTIVE' : 'OPTIONAL', Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10))),
        Text(value, style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: kWebWhite)),
      ],
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _QuickActionCard({required this.label, required this.icon, required this.onTap, this.isActive = false});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final active = _isPressed || _isFocused;
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
        onFocusChange: (v) {
          setState(() => _isFocused = v);
          if (v) handleTVFocusScroll(v, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: Container(
            color: active ? kWebWhite.withValues(alpha: 0.1) : kWebBlack,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.isActive ? DS.success : (active ? kWebWhite : kWebTextMuted), size: 24),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.dmMono(color: active ? kWebWhite : kWebText, fontSize: 9, letterSpacing: 1),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchitectureTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isFirst;

  const _ArchitectureTile({required this.title, required this.subtitle, required this.icon, this.isFirst = false});

  @override
  State<_ArchitectureTile> createState() => _ArchitectureTileState();
}

class _ArchitectureTileState extends State<_ArchitectureTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) handleTVFocusScroll(v, context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _focused ? kWebWhite.withValues(alpha: 0.05) : kWebSurface,
          border: Border(
            bottom: BorderSide(color: kWebBorder), 
            top: widget.isFirst ? BorderSide(color: kWebBorder) : BorderSide.none
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: kWebSurface2, border: Border.all(color: _focused ? kWebWhite : kWebBorder)),
              child: Icon(widget.icon, color: _focused ? kWebWhite : kWebText, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 3),
                  Text(widget.subtitle, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 9, letterSpacing: 1)),
                ],
              ),
            ),
            if (_focused) Icon(LucideIcons.chevronRight, color: kWebWhite, size: 16),
          ],
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final bool isOnline;
  const _BlinkingDot({required this.isOnline});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) return Container(width: 8, height: 8, color: Colors.white24);
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.white, blurRadius: 4)],
        ),
      ),
    );
  }
}
