// presentation/home/role_selection_screen.dart
// ============================================================================
// STREAMZ — Role Selection (Home) Screen (Production-Fixed)
//
// BUGS FIXED:
//   1. On desktop/web, the code jumped directly to ServerDashboard without
//      ever setting permissions_granted = true in SharedPreferences. This
//      caused the flag to stay false forever, so the PermissionScreen kept
//      appearing on subsequent launches even though no permissions were needed.
//      Fixed: write permissions_granted = true before navigating on platforms
//      that don't need runtime permissions.
//   2. No guard against double-tap / rapid navigation — tapping SERVER twice
//      quickly pushed two ServerDashboard routes onto the stack. Added a
//      _navigating flag to debounce the gesture.
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
import '../server/server_viewmodel.dart';
import 'permission_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // FIX: Debounce flag prevents double-navigation on rapid taps.
  bool _navigating = false;

  Future<void> _handleServerTap(BuildContext context) async {
    if (_navigating) return;
    setState(() => _navigating = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // FIX: On platforms that need no runtime permissions, mark granted
      // immediately so the PermissionScreen never appears.
      final isAutoGrantPlatform = kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux;

      if (isAutoGrantPlatform) {
        await prefs.setBool('permissions_granted', true);
      }

      final granted = prefs.getBool('permissions_granted') ?? false;
      if (!context.mounted) return;

      if (granted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(create: (_) => ServerViewModel(), child: const ServerDashboard()),
          ),
        );
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionScreen()));
      }
    } finally {
      // Reset flag after navigation completes (or fails).
      if (mounted) setState(() => _navigating = false);
    }
  }

  void _handleClientTap(BuildContext context) {
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
    return AppScaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(opacity: 0.12, child: const CustomPaint(painter: GridPainter())),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isDesktop = width > DS.bpTablet;
                final isMobile = width <= DS.bpMobile;
                final hPad = DS.hPad(width);
                final vPad = isMobile ? 32.0 : 60.0;
                final titleSz = isDesktop ? 120.0 : (isMobile ? 56.0 : 90.0);

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: isMobile ? 10 : 40),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('STREAM ', style: AppTheme.theme.textTheme.displayLarge?.copyWith(fontSize: titleSz, height: 1.0)),
                              Stack(
                                children: [
                                  Text(
                                    'ANYTHING',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: titleSz,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -2,
                                      height: 1.0,
                                      foreground: Paint()
                                        ..style = PaintingStyle.stroke
                                        ..strokeWidth = isMobile ? 1 : 2
                                        ..color = DS.accent,
                                    ),
                                  ),
                                  Text(
                                    'ANYTHING',
                                    style: GoogleFonts.barlowCondensed(fontSize: titleSz, fontWeight: FontWeight.w900, letterSpacing: -2, height: 1.0, color: Colors.transparent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 24 : 40),
                        Text(
                          'A premium cross-platform broadcasting system. '
                          'Any device becomes a server. Any device becomes a client. '
                          'Zero configuration. Pure signal.',
                          style: AppTheme.theme.textTheme.bodyLarge?.copyWith(fontSize: isMobile ? 14 : 16),
                        ),
                        SizedBox(height: isMobile ? 32 : 80),
                        FocusTraversalGroup(
                          policy: WidgetOrderTraversalPolicy(),
                          child: isDesktop
                              ? IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _RoleCard(
                                          roleText: 'SERVER',
                                          subtitle:
                                              'Host your local media library. UDP broadcasts '
                                              'announce your presence. HTTP serves files.',
                                          icon: LucideIcons.hardDrive,
                                          isMobile: false,
                                          autoFocus: true,
                                          onTap: () => _handleServerTap(context),
                                        ),
                                      ),
                                      const SizedBox(width: DS.s24),
                                      Expanded(
                                        child: _RoleCard(
                                          roleText: 'CLIENT',
                                          subtitle:
                                              'Connect to any Streamz server via UDP '
                                              'auto-discovery or QR scan. Browse, stream, '
                                              'or download.',
                                          icon: LucideIcons.wifiHigh,
                                          isMobile: false,
                                          onTap: () => _handleClientTap(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    _RoleCard(
                                      roleText: 'SERVER',
                                      subtitle:
                                          'Host your local media library. UDP broadcasts '
                                          'announce your presence. HTTP serves files.',
                                      icon: LucideIcons.hardDrive,
                                      isMobile: true,
                                      autoFocus: true,
                                      onTap: () => _handleServerTap(context),
                                    ),
                                    const SizedBox(height: DS.s16),
                                    _RoleCard(
                                      roleText: 'CLIENT',
                                      subtitle:
                                          'Connect to any Streamz server via UDP '
                                          'auto-discovery or QR scan. Browse, stream, '
                                          'or download.',
                                      icon: LucideIcons.wifiHigh,
                                      isMobile: true,
                                      onTap: () => _handleClientTap(context),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
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
// ROLE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  final String roleText;
  final String subtitle;
  final IconData icon;
  final bool isMobile;
  final VoidCallback onTap;
  final bool autoFocus;

  const _RoleCard({required this.roleText, required this.subtitle, required this.icon, required this.isMobile, required this.onTap, this.autoFocus = false});

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isFocused = false;
  bool _isPressed = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: widget.roleText);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isFocused || _isPressed;

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
        focusNode: _focusNode,
        autofocus: widget.autoFocus,
        onFocusChange: (val) {
          setState(() => _isFocused = val);
          handleTVFocusScroll(val, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: isActive ? (widget.isMobile ? 0.98 : 1.03) : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isActive ? DS.surface3 : DS.surface1,
                border: Border.all(color: isActive ? DS.accent : DS.borderDefault, width: isActive ? 3 : 1),
                boxShadow: isActive ? [const BoxShadow(color: DS.accent, offset: Offset(4, 4))] : [],
              ),
              padding: EdgeInsets.all(widget.isMobile ? 24 : 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.roleText,
                      style: GoogleFonts.barlowCondensed(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        fontSize: widget.isMobile ? 40 : 64,
                        color: isActive ? DS.textPrimary : null,
                        foreground: isActive
                            ? null
                            : (Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 1
                                ..color = DS.accent),
                      ),
                    ),
                  ),
                  SizedBox(height: widget.isMobile ? 12 : 24),
                  Text(widget.subtitle, style: AppTheme.theme.textTheme.bodyLarge?.copyWith(fontSize: widget.isMobile ? 12 : 15)),
                  SizedBox(height: widget.isMobile ? 24 : 40),
                  Row(
                    children: [
                      Container(
                        width: widget.isMobile ? 8 : 12,
                        height: widget.isMobile ? 8 : 12,
                        decoration: BoxDecoration(
                          color: DS.accent,
                          shape: BoxShape.circle,
                          boxShadow: isActive ? [BoxShadow(color: DS.accent.withValues(alpha: 0.8), blurRadius: 12, spreadRadius: 6)] : [],
                        ),
                      ),
                      const SizedBox(width: DS.s16),
                      const Expanded(child: Divider(color: DS.borderDefault)),
                      const SizedBox(width: DS.s16),
                      Icon(widget.icon, size: widget.isMobile ? 20 : 24, color: DS.accent),
                    ],
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
