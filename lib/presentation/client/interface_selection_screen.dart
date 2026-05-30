// presentation/client/interface_selection_screen.dart
// ============================================================================
// STREAMZ — Interface Gateway (Post-Connection)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mobile/mobile_selection_screen.dart';
import '../tv/tv_selection_screen.dart';
import '../player/player_screen.dart';
import '../../domain/models/media_item.dart';
import 'client_viewmodel.dart';

class InterfaceSelectionScreen extends StatelessWidget {
  const InterfaceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final stations = vm.stations;

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: DS.bg,
        elevation: 0,
        leading: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                context.read<ClientViewModel>().disconnect();
                Navigator.pop(context);
                return null;
              },
            ),
          },
          child: Focus(
            onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
              context.read<ClientViewModel>().disconnect();
              Navigator.pop(context);
            }),
            child: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 24, color: DS.textPrimary),
              onPressed: () {
                // Disconnect the WebSocket if the user backs out
                context.read<ClientViewModel>().disconnect();
                Navigator.pop(context);
              },
            ),
          ),
        ),
        title: Text('SELECT DEVICE MODE', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
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
                final isMobile = width <= DS.bpMobile;
                final hPad = DS.hPad(width);
                final vPad = isMobile ? 32.0 : 60.0;

                // Dynamically scale the main title
                final titleSize = (width * 0.07).clamp(32.0, 56.0);

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('CONNECTION ESTABLISHED', style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.accent, letterSpacing: 4)),
                        const SizedBox(height: 16),
                        Text(
                          'HOW ARE YOU VIEWING?',
                          style: AppTheme.theme.textTheme.displayMedium?.copyWith(fontSize: titleSize, height: 1.1),
                          textAlign: TextAlign.center,
                        ),
                        if (stations.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _JoinLiveBanner(
                            stations: stations,
                            onJoin: (station) async {
                              final res = await vm.joinStation(station['id']);
                              if (res != null && context.mounted) {
                                final items = (res['playlist'] as List?)?.map((e) => MediaItem.fromJson(e)).toList() ?? [MediaItem.fromJson(res['item'])];
                                final startIndex = res['itemIndex'] as int? ?? 0;
                                final offsetMs = res['positionMs'] as int;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerScreen(
                                      items: items,
                                      startIndex: startIndex,
                                      isPathBased: false,
                                      startOffset: Duration(milliseconds: offsetMs),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                        SizedBox(height: isMobile ? 48 : 80),

                        // Wrapped in FocusTraversalGroup to protect TV D-Pad logic
                        FocusTraversalGroup(
                          policy: WidgetOrderTraversalPolicy(),
                          // Safe breakpoint: only switch to row when there's enough room to breathe
                          child: width >= 650
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 800), // Prevent ultra-wide stretching
                                  child: IntrinsicHeight(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _DeviceCard(
                                            title: 'TV USER',
                                            subtitle: '10-FOOT UI & D-PAD',
                                            icon: LucideIcons.tv,
                                            autoFocus: true, // Grabs focus for physical remotes
                                            isMobileView: false,
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChangeNotifierProvider.value(value: context.read<ClientViewModel>(), child: const TVSelectionScreen()),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: DS.s24),
                                        Expanded(
                                          child: _DeviceCard(
                                            title: 'MOBILE USER',
                                            subtitle: 'TOUCH-OPTIMIZED UI',
                                            icon: LucideIcons.smartphone,
                                            isMobileView: false,
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChangeNotifierProvider.value(value: context.read<ClientViewModel>(), child: const MobileSelectionScreen()),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 400),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _DeviceCard(
                                        title: 'TV USER',
                                        subtitle: '10-FOOT UI & D-PAD',
                                        icon: LucideIcons.tv,
                                        autoFocus: true,
                                        isMobileView: true,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChangeNotifierProvider.value(value: context.read<ClientViewModel>(), child: const TVSelectionScreen()),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: DS.s16),
                                      _DeviceCard(
                                        title: 'MOBILE USER',
                                        subtitle: 'TOUCH-OPTIMIZED UI',
                                        icon: LucideIcons.smartphone,
                                        isMobileView: true,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChangeNotifierProvider.value(value: context.read<ClientViewModel>(), child: const MobileSelectionScreen()),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
// JOIN LIVE BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _JoinLiveBanner extends StatefulWidget {
  final List<Map<String, dynamic>> stations;
  final Function(Map<String, dynamic>) onJoin;

  const _JoinLiveBanner({required this.stations, required this.onJoin});

  @override
  State<_JoinLiveBanner> createState() => _JoinLiveBannerState();
}

class _JoinLiveBannerState extends State<_JoinLiveBanner> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final station = widget.stations.first;
    final title = station['name'].toString().toUpperCase();

    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onJoin(station);
            return null;
          },
        ),
      },
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => widget.onJoin(station)),
        child: GestureDetector(
          onTap: () => widget.onJoin(station),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: _focused ? DS.accent : DS.surface2,
              border: Border.all(color: _focused ? DS.accent : DS.borderDefault, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.radio, color: _focused ? DS.bg : DS.accent, size: 20),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('LIVE BROADCAST ACTIVE', style: GoogleFonts.dmMono(fontSize: 10, color: _focused ? DS.bg : DS.textMuted, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('JOIN $title', style: AppTheme.theme.textTheme.labelMedium?.copyWith(color: _focused ? DS.bg : DS.textPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 24),
                Icon(LucideIcons.chevronRight, color: _focused ? DS.bg : DS.textMuted, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool autoFocus;
  final bool isMobileView;

  const _DeviceCard({required this.title, required this.subtitle, required this.icon, required this.onTap, this.autoFocus = false, required this.isMobileView});

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool _isFocused = false;
  bool _isPressed = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: widget.title);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isFocused || _isPressed;
    final padding = widget.isMobileView ? 32.0 : 48.0;
    final iconSize = widget.isMobileView ? 48.0 : 64.0;

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
          if (val) handleTVFocusScroll(val, context);
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
            scale: isActive ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isActive ? DS.surface3 : DS.surface1,
                border: Border.all(color: isActive ? DS.accent : DS.borderDefault, width: isActive ? 3 : 1),
                boxShadow: isActive ? [const BoxShadow(color: DS.accent, offset: Offset(4, 4))] : [],
              ),
              padding: EdgeInsets.symmetric(horizontal: DS.s24, vertical: padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: iconSize, color: isActive ? DS.accent : DS.textPrimary),
                  const SizedBox(height: DS.s24),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.title,
                      style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900, letterSpacing: -1, fontSize: 40, color: DS.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    style: AppTheme.theme.textTheme.bodyLarge?.copyWith(fontSize: 12, color: DS.textMuted, letterSpacing: 2),
                    textAlign: TextAlign.center,
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
