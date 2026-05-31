// presentation/home/role_selection_screen.dart
// ============================================================================
// STREAMZ — Role Selection (NOC Dashboard)
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../client/client_connect_screen.dart';
import '../client/client_viewmodel.dart';
import '../server/server_dashboard.dart';
import 'permission_screen.dart';
import 'role_selection_screen_tv.dart';

// --- Web UI Color Palette & Styles (Synced with System Dashboards) ---
const Color kWebBlack = Color(0xFF000000);
const Color kWebSurface = Color(0xFF0A0A0A);
const Color kWebSurface2 = Color(0xFF111111);
const Color kWebWhite = Color(0xFFFFFFFF);
final Color kWebBorder = Colors.white.withValues(alpha: 0.15);
final Color kWebTextMuted = Colors.white.withValues(alpha: 0.3);
final Color kWebText = Colors.white.withValues(alpha: 0.6);

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _navigating = false;

  Future<void> _handleServerTap() async {
    if (_navigating) return;
    setState(() => _navigating = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final isAutoGrantPlatform = kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux;

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
    if (DS.isTV(context)) {
      return const RoleSelectionScreenTV();
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
      centerTitle: true,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'STREAMZ NOC',
                  style: GoogleFonts.barlowCondensed(
                    color: kWebWhite,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kWebBorder, height: 1),
      ),
    );
  }

  Widget _buildBody(bool isMobile) {
    if (isMobile) {
      return SliverList(
        delegate: SliverChildListDelegate([
          _SystemStatusCard(isMobile: isMobile),
          Container(
            decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)), color: kWebBorder),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              children: [
                _QuickActionCard(
                  label: 'HOST SERVER',
                  subLabel: 'BROADCAST ENGINE',
                  code: '01',
                  icon: LucideIcons.hardDrive,
                  onTap: _handleServerTap,
                ),
                _QuickActionCard(
                  label: 'JOIN NODE',
                  subLabel: 'SYNCHRONIZE',
                  code: '02',
                  icon: LucideIcons.wifiHigh,
                  onTap: _handleClientTap,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('CORE ARCHITECTURE', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
          ),
          _ArchitectureTile(title: 'BROADCAST ENGINE', subtitle: 'UDP DISCOVERY // HTTP DATA STREAM', icon: LucideIcons.zap, isFirst: true),
          _ArchitectureTile(title: 'DISTRIBUTED NODES', subtitle: 'MULTI-CLIENT SYNCHRONIZATION', icon: LucideIcons.share2),
          _ArchitectureTile(title: 'LOCAL PERSISTENCE', subtitle: 'SECURE CREDENTIAL STORAGE', icon: LucideIcons.lock),
          const SizedBox(height: 100),
        ]),
      );
    }

    // Desktop / TV Layout (2-Column)
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: kWebBorder), right: BorderSide(color: kWebBorder))),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SystemStatusCard(isMobile: false),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text('CORE ARCHITECTURE', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
                        ),
                        _ArchitectureTile(title: 'BROADCAST ENGINE', subtitle: 'UDP DISCOVERY // HTTP DATA STREAM', icon: LucideIcons.zap, isFirst: true),
                        _ArchitectureTile(title: 'DISTRIBUTED NODES', subtitle: 'MULTI-CLIENT SYNCHRONIZATION', icon: LucideIcons.share2),
                        _ArchitectureTile(title: 'LOCAL PERSISTENCE', subtitle: 'SECURE CREDENTIAL STORAGE', icon: LucideIcons.lock),
                      ],
                    ),
                  ),
                  Container(width: 1, color: kWebBorder),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            label: 'HOST SERVER',
                            subLabel: 'BROADCAST ENGINE',
                            code: '01',
                            icon: LucideIcons.hardDrive,
                            onTap: _handleServerTap,
                          ),
                        ),
                        Container(height: 1, color: kWebBorder),
                        Expanded(
                          child: _QuickActionCard(
                            label: 'JOIN NODE',
                            subLabel: 'SYNCHRONIZE',
                            code: '02',
                            icon: LucideIcons.wifiHigh,
                            onTap: _handleClientTap,
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
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  final bool isMobile;
  const _SystemStatusCard({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform.toString().split('.').last.toUpperCase();

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
              Text('SYSTEM ANALYSIS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const _BlinkingDot(isOnline: true),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLATFORM', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(platform, style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('STATUS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('READY', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold)),
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
                widthFactor: 1.0,
                child: Container(height: 8, color: kWebWhite),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Expanded(child: _legend('VERSION', 'v2.0.4-PROD', kWebWhite)),
              const SizedBox(width: 16),
              Expanded(child: _legend('ARCHITECTURE', 'BRUTALIST', Colors.white70)),
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
  final String subLabel;
  final String code;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.subLabel,
    required this.code,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isPressed || _isFocused;
    final bgColor = isActive ? DS.surface4 : kWebSurface2;

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
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapCancel: () => setState(() => _isPressed = false),
          onHighlightChanged: (v) => setState(() => _isPressed = v),
          onHover: (v) => setState(() => _isFocused = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: bgColor,
            child: Stack(
              children: [
                // Faint Technical Grid Background
                Positioned.fill(
                  child: CustomPaint(
                    painter: GridPainter(
                      spacing: 20,
                      color: isActive ? kWebWhite.withValues(alpha: 0.05) : kWebWhite.withValues(alpha: 0.02),
                    ),
                  ),
                ),

                // Corner Brackets (Brutalist/NOC Aesthetic)
                _buildCorner(Alignment.topLeft, isActive),
                _buildCorner(Alignment.topRight, isActive),
                _buildCorner(Alignment.bottomLeft, isActive),
                _buildCorner(Alignment.bottomRight, isActive),

                // Content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status Code / Index
                      Text(
                        'SYS_TYPE // ${widget.code}',
                        style: GoogleFonts.dmMono(
                          color: isActive ? kWebWhite : kWebTextMuted,
                          fontSize: 8,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isActive ? 1.2 : 1.0,
                        child: Icon(
                          widget.icon,
                          color: isActive ? kWebWhite : kWebText,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.label,
                        style: GoogleFonts.barlowCondensed(
                          color: kWebWhite,
                          fontSize: 18,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subLabel,
                        style: GoogleFonts.dmMono(
                          color: isActive ? kWebWhite : kWebTextMuted,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Focus/Active Indicator (Brutalist Border)
                if (isActive)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: kWebWhite, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment, bool isActive) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight ? BorderSide(color: isActive ? kWebWhite : kWebBorder, width: 1.5) : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? BorderSide(color: isActive ? kWebWhite : kWebBorder, width: 1.5) : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? BorderSide(color: isActive ? kWebWhite : kWebBorder, width: 1.5) : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? BorderSide(color: isActive ? kWebWhite : kWebBorder, width: 1.5) : BorderSide.none,
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
