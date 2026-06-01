// presentation/tv/tv_selection_screen.dart
// ============================================================================
// STREAMZ — TV Interface Selection Gateway (Samsung-Style)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../client/client_viewmodel.dart';
import '../player/player_screen.dart';
import '../../domain/models/media_item.dart';
import 'tv_file_manager.dart';
import 'tv_home_screen.dart';
import 'tv_selection_screen_tv.dart';

// --- Web UI Color Palette & Styles (Synced with System Dashboards) ---
const Color kWebBlack = Color(0xFF000000);
const Color kWebSurface = Color(0xFF0A0A0A);
const Color kWebSurface2 = Color(0xFF111111);
const Color kWebWhite = Color(0xFFFFFFFF);
final Color kWebBorder = Colors.white.withValues(alpha: 0.15);
final Color kWebTextMuted = Colors.white.withValues(alpha: 0.3);
final Color kWebText = Colors.white.withValues(alpha: 0.6);

class TVSelectionScreen extends StatelessWidget {
  const TVSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (DS.isTV(context)) {
      return const TVSelectionScreenTV();
    }

    final vm = context.watch<ClientViewModel>();

    return Scaffold(
      backgroundColor: kWebBlack,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context, vm),
            _buildBody(context, vm),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ClientViewModel vm) {
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
        'TV INTERFACE',
        style: GoogleFonts.barlowCondensed(
          color: kWebWhite, 
          fontSize: 20, 
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

  Widget _buildBody(BuildContext context, ClientViewModel vm) {
    return SliverList(
      delegate: SliverChildListDelegate([
        _SessionAnalysisCard(vm: vm, mode: 'TV MODE'),
        
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
                label: 'MODERN UI',
                icon: LucideIcons.tv,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(value: vm, child: const TVHomeScreen()),
                  ),
                ),
              ),
              _QuickActionCard(
                label: 'FILE SYSTEM',
                icon: LucideIcons.folderOpen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(value: vm, child: const TVFileManagerScreen()),
                  ),
                ),
              ),
              _QuickActionCard(
                label: 'DISCONNECT',
                icon: LucideIcons.power,
                onTap: () {
                  vm.disconnect();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('LIVE SIGNALS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
        ),
        
        if (vm.stations.isEmpty)
          _EmptySignalsPlaceholder()
        else
          ...vm.stations.asMap().entries.map((e) => _StationTile(
            station: e.value, 
            isFirst: e.key == 0, 
            onTap: () => _tuneIn(context, vm, e.value),
          )),
          
        const SizedBox(height: 100),
      ]),
    );
  }

  void _tuneIn(BuildContext context, ClientViewModel vm, Map<String, dynamic> station) async {
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
  }
}

class _SessionAnalysisCard extends StatelessWidget {
  final ClientViewModel vm;
  final String mode;
  const _SessionAnalysisCard({required this.vm, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Text('SESSION ANALYSIS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              _BlinkingDot(isOnline: vm.isConnected),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTIVE MODE', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(mode, style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('HOST IP', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(vm.targetIp.toUpperCase(), style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(height: 8, color: kWebSurface2),
              if (vm.isConnected)
                FractionallySizedBox(
                  widthFactor: 1.0, 
                  child: Container(height: 8, color: kWebWhite),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _legend('ASSETS', '${vm.remoteMedia.length} INDEXED', kWebWhite)),
              const SizedBox(width: 16),
              Expanded(child: _legend('SIGNAL', 'STABLE', Colors.white70)),
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

  const _QuickActionCard({required this.label, required this.icon, required this.onTap});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isPressed || _isFocused;
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
            color: isActive ? kWebWhite.withValues(alpha: 0.1) : kWebBlack,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: isActive ? DS.accent : kWebWhite, size: 24),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.dmMono(color: isActive ? kWebWhite : kWebText, fontSize: 9, letterSpacing: 1),
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

class _StationTile extends StatefulWidget {
  final Map<String, dynamic> station;
  final bool isFirst;
  final VoidCallback onTap;

  const _StationTile({required this.station, required this.isFirst, required this.onTap});

  @override
  State<_StationTile> createState() => _StationTileState();
}

class _StationTileState extends State<_StationTile> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _pressed || _focused;
    final title = widget.station['name'].toString().toUpperCase();
    final nowPlaying = widget.station['nowPlaying'];
    final itemTitle = nowPlaying != null ? nowPlaying['item']['title'].toString().toUpperCase() : 'AWAITING SIGNAL';

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
          setState(() => _focused = v);
          if (v) handleTVFocusScroll(v, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? kWebWhite.withValues(alpha: 0.1) : kWebSurface,
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
                  decoration: BoxDecoration(color: kWebSurface2, border: Border.all(color: kWebBorder)),
                  child: Icon(LucideIcons.radio, color: isActive ? DS.accent : kWebText, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 3),
                      Text('LIVE: $itemTitle', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 9, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: kWebTextMuted, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySignalsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: kWebBorder))),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.radioTower, size: 40, color: kWebTextMuted),
            const SizedBox(height: 12),
            Text('NO LIVE BROADCASTS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 4)),
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
