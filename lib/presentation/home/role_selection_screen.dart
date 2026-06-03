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
import '../shared/theme_settings_screen.dart';
import 'permission_screen.dart';
import 'role_selection_screen_tv.dart';

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

    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [_buildSliverAppBar(), _buildBody()],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final tokens = context.tokens;
    return SliverAppBar(
      backgroundColor: tokens.surface1,
      floating: true,
      elevation: 0,
      pinned: true,
      centerTitle: true,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'STREAMZ NOC',
                  style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4),
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.settings, color: tokens.textPrimary),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen())),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
      ),
    );
  }

  Widget _buildBody() {
    final tokens = context.tokens;
    return SliverList(
      delegate: SliverChildListDelegate([
        const _SystemStatusCard(),
        Container(
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            color: tokens.border.withValues(alpha: 0.15),
          ),
          child: GridView.count(
            childAspectRatio: 2,
            crossAxisCount: 1,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            children: [
              _QuickActionCard(label: 'HOST SERVER', subLabel: 'BROADCAST ENGINE', code: '01', icon: LucideIcons.hardDrive, onTap: _handleServerTap),
              _QuickActionCard(label: 'JOIN NODE', subLabel: 'SYNCHRONIZE', code: '02', icon: LucideIcons.wifiHigh, onTap: _handleClientTap),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard();

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform.toString().split('.').last.toUpperCase();
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SYSTEM ANALYSIS',
                style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const _BlinkingDot(isOnline: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLATFORM', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      platform,
                      style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('STATUS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      'READY',
                      style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(height: 8, color: tokens.surface2),
              FractionallySizedBox(widthFactor: 1.0, child: Container(height: 8, color: tokens.accent)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _legend(context, 'VERSION', 'v2.0.4-PROD', tokens.accent)),
              const SizedBox(width: 16),
              Expanded(child: _legend(context, 'ARCHITECTURE', 'BRUTALIST', tokens.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, String label, String value, Color color) {
    final tokens = context.tokens;
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10)),
        ),
        Text(
          value,
          style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textPrimary),
        ),
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

  const _QuickActionCard({required this.label, required this.subLabel, required this.code, required this.icon, required this.onTap});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isActive = _isPressed || _isFocused;
    final bgColor = isActive ? tokens.surface4 : tokens.background;

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
                // Corner Brackets (Brutalist/NOC Aesthetic)
                _buildCorner(context, Alignment.topLeft, isActive),
                _buildCorner(context, Alignment.topRight, isActive),
                _buildCorner(context, Alignment.bottomLeft, isActive),
                _buildCorner(context, Alignment.bottomRight, isActive),

                // Content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isActive ? 1.2 : 1.0,
                        child: Icon(widget.icon, color: isActive ? tokens.accent : tokens.textSecondary, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.label,
                        style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subLabel,
                        style: GoogleFonts.dmMono(color: isActive ? tokens.textPrimary : tokens.textMuted, fontSize: 9, letterSpacing: 1),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Focus/Active Indicator (Brutalist Border)
                if (isActive)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: tokens.accent, width: 2)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(BuildContext context, Alignment alignment, bool isActive) {
    final tokens = context.tokens;
    return Align(
      alignment: alignment,
      child: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight ? BorderSide(color: tokens.textPrimary, width: 1.5) : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? BorderSide(color: tokens.textPrimary, width: 1.5) : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? BorderSide(color: tokens.textPrimary, width: 1.5) : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? BorderSide(color: tokens.textPrimary, width: 1.5) : BorderSide.none,
          ),
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
    final tokens = context.tokens;
    if (!widget.isOnline) return Container(width: 8, height: 8, color: tokens.textMuted.withValues(alpha: 0.3));
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
