// presentation/client/interface_selection_screen.dart
// ============================================================================
// STREAMZ — Interface Gateway (Samsung-Style / Brutalist Edition)
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
import 'interface_selection_screen_tv.dart';

// --- Web UI Color Palette & Styles (Synced with Server/Client Dashboard) ---
const Color kWebBlack = Color(0xFF000000);
const Color kWebSurface = Color(0xFF0A0A0A);
const Color kWebSurface2 = Color(0xFF111111);
const Color kWebWhite = Color(0xFFFFFFFF);
final Color kWebBorder = Colors.white.withValues(alpha: 0.15);
final Color kWebTextMuted = Colors.white.withValues(alpha: 0.3);
final Color kWebText = Colors.white.withValues(alpha: 0.6);

class InterfaceSelectionScreen extends StatelessWidget {
  const InterfaceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (DS.isTV(context)) {
      return const InterfaceSelectionScreenTV();
    }

    final vm = context.watch<ClientViewModel>();
    final isMobile = DS.isMobile(context);

    return Scaffold(
      backgroundColor: kWebBlack,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context, isMobile, vm),
            _buildBody(context, isMobile, vm),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isMobile, ClientViewModel vm) {
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
              vm.disconnect();
              Navigator.pop(context);
              return null;
            },
          ),
        },
        child: Focus(
          onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
            vm.disconnect();
            Navigator.pop(context);
          }),
          child: IconButton(
            icon: Icon(LucideIcons.arrowLeft, size: 20, color: kWebWhite),
            onPressed: () {
              vm.disconnect();
              Navigator.pop(context);
            },
          ),
        ),
      ),
      title: Text(
        'GATEWAY MODE',
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

  Widget _buildBody(BuildContext context, bool isMobile, ClientViewModel vm) {
    return SliverList(
      delegate: SliverChildListDelegate([
        _GatewayAnalysisCard(vm: vm, isMobile: isMobile),
        
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
                label: 'TV USER',
                icon: LucideIcons.tv,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(value: vm, child: const TVSelectionScreen()),
                  ),
                ),
              ),
              _QuickActionCard(
                label: 'MOBILE USER',
                icon: LucideIcons.smartphone,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(value: vm, child: const MobileSelectionScreen()),
                  ),
                ),
              ),
              _QuickActionCard(
                label: 'TERMINATE',
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

class _GatewayAnalysisCard extends StatelessWidget {
  final ClientViewModel vm;
  final bool isMobile;
  const _GatewayAnalysisCard({required this.vm, required this.isMobile});

  @override
  Widget build(BuildContext context) {
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
              Text('GATEWAY ANALYSIS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              _BlinkingDot(isOnline: vm.isConnected),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LINK STATUS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(vm.isConnected ? 'ESTABLISHED' : 'SEVERED', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('UPSTREAM', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
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
          SizedBox(height: isMobile ? 20 : 24),
          Stack(
            children: [
              Container(height: 8, color: kWebSurface2),
              if (vm.isConnected)
                FractionallySizedBox(
                  widthFactor: 1.0, // Solid bar for stable connection
                  child: Container(height: 8, color: kWebWhite),
                ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Expanded(child: _legend('STATIONS', '${vm.stations.length} ACTIVE', kWebWhite)),
              const SizedBox(width: 16),
              Expanded(child: _legend('LATENCY', 'OPTIMAL', Colors.white70)),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        color: _isPressed ? kWebWhite.withValues(alpha: 0.1) : kWebSurface2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: kWebWhite, size: 24),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: GoogleFonts.dmMono(color: kWebText, fontSize: 9, letterSpacing: 1),
              textAlign: TextAlign.center,
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final title = widget.station['name'].toString().toUpperCase();
    final nowPlaying = widget.station['nowPlaying'];
    final itemTitle = nowPlaying != null ? nowPlaying['item']['title'].toString().toUpperCase() : 'AWAITING SIGNAL';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        decoration: BoxDecoration(
          color: _pressed ? kWebWhite.withValues(alpha: 0.1) : kWebSurface,
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
              child: Icon(LucideIcons.radio, color: kWebText, size: 20),
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
