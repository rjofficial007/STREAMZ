// presentation/home/role_selection_screen_tv.dart
// ============================================================================
// STREAMZ — TV Role Selection (NOC Dashboard)
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/theme_service.dart';
import '../client/client_connect_screen.dart';
import '../client/client_viewmodel.dart';
import '../server/server_dashboard.dart';
import '../shared/noc_decorations.dart';
import 'permission_screen.dart';

class RoleSelectionScreenTV extends StatefulWidget {
  const RoleSelectionScreenTV({super.key});

  @override
  State<RoleSelectionScreenTV> createState() => _RoleSelectionScreenTVState();
}

class _RoleSelectionScreenTVState extends State<RoleSelectionScreenTV> {
  bool _navigating = false;

  Future<void> _handleServerTap() async {
    if (_navigating) return;
    setState(() => _navigating = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final isAutoGrantPlatform = kIsWeb ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux;

      if (isAutoGrantPlatform) {
        await prefs.setBool('permissions_granted', true);
      }

      final granted = prefs.getBool('permissions_granted') ?? false;
      if (!mounted) return;

      if (granted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerDashboard()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionScreen()));
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  void _handleClientTap() {
    if (_navigating) return;
    setState(() => _navigating = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(create: (_) => ClientViewModel(), child: const ClientConnectScreen()),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _navigating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final themeService = context.watch<ThemeService>();

    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: tokens.background,
      body: Stack(
        children: [
          // Background Grid
          Positioned.fill(
            child: NocGridBackground(
              spacing: (size.width * 0.04).clamp(30.0, 60.0),
              color: tokens.borderSubtle,
            ),
          ),

          if (!themeService.reducedMotion)
            Positioned.fill(
              child: NocScanningLine(
                color: tokens.accent.withValues(alpha: 0.03),
                reducedMotion: themeService.reducedMotion,
              ),
            ),

          // Main Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _TVActionCard(
                              label: 'HOST SERVER',
                              subLabel: 'BROADCAST ENGINE',
                              code: 'SRV-01',
                              icon: LucideIcons.hardDrive,
                              onTap: _handleServerTap,
                              autofocus: true,
                            ),
                          ),
                          const SizedBox(width: DS.s40),
                          Expanded(
                            child: _TVActionCard(
                              label: 'JOIN NODE',
                              subLabel: 'SYNCHRONIZE',
                              code: 'NOD-02',
                              icon: LucideIcons.wifiHigh,
                              onTap: _handleClientTap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final platform = defaultTargetPlatform.toString().split('.').last.toUpperCase();
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);
    final verticalPad = (size.height * 0.04).clamp(16.0, 40.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STREAMZ NOC // SYSTEM ANALYSIS',
                  style: GoogleFonts.barlowCondensed(
                    color: tokens.textPrimary,
                    fontSize: (size.width * 0.02).clamp(20.0, 32.0),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: DS.s8),
                Container(height: 2, width: (size.width * 0.1).clamp(100.0, 200.0), color: tokens.accent),
              ],
            ),
          ),
          _StatusModule(label: 'PLATFORM', value: platform),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          const _StatusModule(label: 'STATUS', value: 'READY'),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          const _StatusModule(label: 'VERSION', value: 'v2.0.4-PROD'),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);
    final verticalPad = (size.height * 0.04).clamp(16.0, 40.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
      child: Row(
        children: [
          Text(
            'CORE ARCHITECTURE: BRUTALIST // UDP_DISCOVERY // HTTP_STREAM',
            style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: (size.width * 0.008).clamp(9.0, 12.0), letterSpacing: 2),
          ),
          const Spacer(),
          const _BlinkingDotTV(),
        ],
      ),
    );
  }
}

class _StatusModule extends StatelessWidget {
  final String label;
  final String value;
  const _StatusModule({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TVActionCard extends StatefulWidget {
  final String label;
  final String subLabel;
  final String code;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;

  const _TVActionCard({
    required this.label,
    required this.subLabel,
    required this.code,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_TVActionCard> createState() => _TVActionCardState();
}

class _TVActionCardState extends State<_TVActionCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused ? tokens.surface3 : tokens.surface1;
    final borderColor = _isFocused ? tokens.accent : tokens.border;
    final size = MediaQuery.sizeOf(context);

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) {
        setState(() => _isFocused = v);
        if (v) handleTVFocusScroll(v, context);
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: (size.height * 0.5).clamp(280.0, 450.0),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: _isFocused ? 4 : 1),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                // Inner Grid for Card
                Positioned.fill(
                  child: NocGridBackground(
                    spacing: 20,
                    color: _isFocused ? tokens.accent.withValues(alpha: 0.05) : tokens.borderSubtle,
                  ),
                ),

                // Corner Brackets
                _buildCorner(context, Alignment.topLeft),
                _buildCorner(context, Alignment.topRight),
                _buildCorner(context, Alignment.bottomLeft),
                _buildCorner(context, Alignment.bottomRight),

                // Content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SYS_TYPE // ${widget.code}',
                        style: GoogleFonts.dmMono(
                          color: _isFocused ? tokens.textPrimary : tokens.textMuted,
                          fontSize: (size.width * 0.008).clamp(9.0, 12.0),
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: (size.height * 0.04).clamp(16.0, 40.0)),
                      Icon(
                        widget.icon,
                        color: _isFocused ? tokens.textPrimary : tokens.textSecondary,
                        size: (size.width * 0.05).clamp(40.0, 80.0),
                      ),
                      SizedBox(height: (size.height * 0.04).clamp(16.0, 40.0)),
                      Text(
                        widget.label,
                        style: GoogleFonts.barlowCondensed(
                          color: tokens.textPrimary,
                          fontSize: (size.width * 0.025).clamp(24.0, 48.0),
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DS.s8),
                      Text(
                        widget.subLabel,
                        style: GoogleFonts.dmMono(
                          color: _isFocused ? tokens.textPrimary : tokens.textMuted,
                          fontSize: (size.width * 0.009).clamp(10.0, 14.0),
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildCorner(BuildContext context, Alignment alignment) {
    final tokens = context.tokens;
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight ? BorderSide(color: _isFocused ? tokens.accent : tokens.borderStrong, width: 3) : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? BorderSide(color: _isFocused ? tokens.accent : tokens.borderStrong, width: 3) : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? BorderSide(color: _isFocused ? tokens.accent : tokens.borderStrong, width: 3) : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? BorderSide(color: _isFocused ? tokens.accent : tokens.borderStrong, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _BlinkingDotTV extends StatefulWidget {
  const _BlinkingDotTV();

  @override
  State<_BlinkingDotTV> createState() => _BlinkingDotTVState();
}

class _BlinkingDotTVState extends State<_BlinkingDotTV> with SingleTickerProviderStateMixin {
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
    final tokens = context.tokens;
    return FadeTransition(
      opacity: _ctrl,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: tokens.success,
              boxShadow: [BoxShadow(color: tokens.success, blurRadius: 10)],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'SYSTEM ONLINE',
            style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}
