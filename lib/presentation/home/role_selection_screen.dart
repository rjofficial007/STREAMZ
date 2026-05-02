// presentation/home/role_selection_screen.dart
// ============================================================================
// STREAMZ — Role Selection (Home) Screen
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../client/client_connect_screen.dart';
import '../client/client_viewmodel.dart';
import '../server/server_dashboard.dart';
import '../server/server_viewmodel.dart';
import 'permission_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _handleServerTap(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final granted = prefs.getBool('permissions_granted') ?? false;

    if (!context.mounted) return;

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux || granted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(create: (_) => ServerViewModel(), child: const ServerDashboard()),
        ),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionScreen()));
    }
  }

  void _handleClientTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(create: (_) => ClientViewModel(), child: const ClientConnectScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Stack(
        children: [
          // Background grid
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

                        // Hero headline
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
                                  // Outlined italic "ANYTHING"
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
                                  // Transparent fill to preserve layout
                                  Text(
                                    'ANYTHING',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: titleSz,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -2,
                                      height: 1.0,
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isMobile ? 24 : 40),

                        // Subtitle
                        Text(
                          'A premium cross-platform broadcasting system. '
                              'Any device becomes a server. Any device becomes a client. '
                              'Zero configuration. Pure signal.',
                          style: AppTheme.theme.textTheme.bodyLarge?.copyWith(fontSize: isMobile ? 14 : 16),
                        ),

                        SizedBox(height: isMobile ? 32 : 80),

                        // Role cards wrapped in FocusTraversalGroup to guarantee D-Pad behavior
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
                                    icon: PhosphorIconsFill.hardDrives,
                                    isMobile: false,
                                    autoFocus: true, // Grabs physical TV remote focus on boot
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
                                    icon: PhosphorIconsFill.wifiHigh,
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
                                icon: PhosphorIconsFill.hardDrives,
                                isMobile: true,
                                autoFocus: true, // Grabs physical TV remote focus on boot
                                onTap: () => _handleServerTap(context),
                              ),
                              const SizedBox(height: DS.s16),
                              _RoleCard(
                                roleText: 'CLIENT',
                                subtitle:
                                'Connect to any Streamz server via UDP '
                                    'auto-discovery or QR scan. Browse, stream, '
                                    'or download.',
                                icon: PhosphorIconsFill.wifiHigh,
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
    // Persistent FocusNode prevents TV cursor from dropping during LayoutBuilder rebuilds
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
          // Uses the safe global scroll helper instead of a synchronous Scrollable.ensureVisible
          // to prevent crashing the TV layout engine on frame 1.
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
            scale: isActive ? (widget.isMobile ? 0.98 : 1.03) : 1.0, // Scale down on touch, scale up on TV Focus
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
                  // Outlined role label
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.roleText,
                      style: GoogleFonts.barlowCondensed(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        fontSize: widget.isMobile ? 40 : 64,
                        color: isActive ? DS.textPrimary : null, // Set color to null if inactive
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
                  // Decorative bottom row
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