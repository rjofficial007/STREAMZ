// presentation/client/interface_selection_screen.dart
// ============================================================================
// STREAMZ — Interface Gateway (Samsung-Style / Brutalist Edition)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/history_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/client/interface_selection_screen_tv.dart';

class InterfaceSelectionScreen extends StatefulWidget {
  const InterfaceSelectionScreen({super.key});

  @override
  State<InterfaceSelectionScreen> createState() => _InterfaceSelectionScreenState();
}

class _InterfaceSelectionScreenState extends State<InterfaceSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientViewModel>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (DS.isTV(context)) {
      return const InterfaceSelectionScreenTV();
    }

    final vm = context.watch<ClientViewModel>();
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.background,
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
    final tokens = context.tokens;
    return SliverAppBar(
      backgroundColor: tokens.surface1,
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
            icon: Icon(LucideIcons.arrowLeft, size: 20, color: tokens.textPrimary),
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
          color: tokens.textPrimary, 
          fontSize: 20, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 4
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(LucideIcons.refreshCw, size: 20, color: tokens.textPrimary),
          onPressed: () => vm.refresh(),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: tokens.textPrimary, height: 1),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ClientViewModel vm) {
    final tokens = context.tokens;
    return SliverList(
      delegate: SliverChildListDelegate([
        _GatewayAnalysisCard(vm: vm),
        
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: tokens.textPrimary)), 
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    label: 'TV USER',
                    icon: LucideIcons.tv,
                    onTap: () => context.push('/client/tv'),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: tokens.textPrimary),
                Expanded(
                  child: _QuickActionCard(
                    label: 'MOBILE USER',
                    icon: LucideIcons.smartphone,
                    onTap: () => context.push('/client/mobile'),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: tokens.textPrimary),
                Expanded(
                  child: _QuickActionCard(
                    label: 'TERMINATE',
                    icon: LucideIcons.power,
                    onTap: () {
                      vm.disconnect();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('LIVE SIGNALS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 2)),
        ),
        
        if (vm.stations.isEmpty)
          _EmptySignalsPlaceholder()
        else
          ...vm.stations.asMap().entries.map((e) => _StationTile(
            station: e.value, 
            isFirst: e.key == 0, 
            onTap: () => _tuneIn(context, vm, e.value),
          )),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('RECENTLY VIEWED', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 2)),
        ),

        if (vm.localHistory.isEmpty)
           Padding(
            padding: const EdgeInsets.all(16),
            child: Text('NO HISTORY FOUND', style: GoogleFonts.dmMono(color: tokens.textDisabled, fontSize: 9, letterSpacing: 2)),
          )
        else
          ...vm.localHistory.asMap().entries.map((e) => _ViewHistoryTile(
            item: e.value, 
            isFirst: e.key == 0,
            onTap: () {
               context.push('/player', extra: {
                'items': [e.value.media],
                'startIndex': 0,
                'isPathBased': false,
              });
            },
          )),
          
        const SizedBox(height: 100),
      ]),
    );
  }

  Future<void> _tuneIn(BuildContext context, ClientViewModel vm, BroadcastStation station) async {
    final res = await vm.joinStation(station.id);
    if (res != null && context.mounted) {
      unawaited(context.push('/player', extra: {
        'items': res.playlist,
        'startIndex': res.itemIndex,
        'isPathBased': false,
        'startOffset': res.position,
      }));
    }
  }
}


class _GatewayAnalysisCard extends StatelessWidget {
  const _GatewayAnalysisCard({required this.vm});
  final ClientViewModel vm;

  @override
  Widget build(BuildContext context) {
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
              Text('GATEWAY ANALYSIS', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                    Text('LINK STATUS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(vm.isConnected ? 'ESTABLISHED' : 'SEVERED', style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('UPSTREAM', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(vm.targetIp.toUpperCase(), style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
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
              if (vm.isConnected)
                FractionallySizedBox(
                  widthFactor: 1.0, // Solid bar for stable connection
                  child: Container(height: 8, color: tokens.accent),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _legend(context, 'STATIONS', '${vm.stations.length} ACTIVE', tokens.textPrimary)),
              const SizedBox(width: 16),
              Expanded(child: _legend(context, 'LATENCY', 'OPTIMAL', tokens.textSecondary)),
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
        Expanded(child: Text(label, style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10))),
        Text(value, style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
      ],
    );
  }
}

class _QuickActionCard extends StatefulWidget {

  const _QuickActionCard({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

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
    return Focus(
      onFocusChange: (v) => setState(() => _isFocused = v),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: isActive ? tokens.textPrimary.withValues(alpha: 0.1) : tokens.surface2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: tokens.textPrimary, size: 24),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: GoogleFonts.dmMono(color: tokens.textSecondary, fontSize: 9, letterSpacing: 1),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationTile extends StatefulWidget {

  const _StationTile({required this.station, required this.isFirst, required this.onTap});
  final BroadcastStation station;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  State<_StationTile> createState() => _StationTileState();
}

class _StationTileState extends State<_StationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = widget.station.name.toUpperCase();
    final nowPlaying = widget.station.nowPlaying;
    final itemTitle = nowPlaying != null ? nowPlaying.item.title.toUpperCase() : 'AWAITING SIGNAL';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        decoration: BoxDecoration(
          color: _pressed ? tokens.textPrimary.withValues(alpha: 0.1) : tokens.surface1,
          border: Border(
            bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)), 
            top: widget.isFirst ? BorderSide(color: tokens.border.withValues(alpha: 0.15)) : BorderSide.none
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tokens.surface2, border: Border.all(color: tokens.border.withValues(alpha: 0.15))),
              child: Icon(LucideIcons.radio, color: tokens.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 3),
                  Text('LIVE: $itemTitle', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: tokens.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ViewHistoryTile extends StatefulWidget {

  const _ViewHistoryTile({required this.item, required this.isFirst, required this.onTap});
  final HistoryItem item;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  State<_ViewHistoryTile> createState() => _ViewHistoryTileState();
}

class _ViewHistoryTileState extends State<_ViewHistoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = widget.item.media.title.toUpperCase();
    final time = '${widget.item.timestamp.day}/${widget.item.timestamp.month} ${widget.item.timestamp.hour}:${widget.item.timestamp.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        decoration: BoxDecoration(
          color: _pressed ? tokens.textPrimary.withValues(alpha: 0.1) : tokens.surface1,
          border: Border(
            bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)), 
            top: widget.isFirst ? BorderSide(color: tokens.border.withValues(alpha: 0.15)) : BorderSide.none
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tokens.surface2, border: Border.all(color: tokens.border.withValues(alpha: 0.15))),
              child: Icon(widget.item.media.isVideo ? LucideIcons.video : LucideIcons.music, color: tokens.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text('VIEWED: $time', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 1)),
                ],
              ),
            ),
            Icon(LucideIcons.play, color: tokens.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _EmptySignalsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.radioTower, size: 40, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text('NO LIVE BROADCASTS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 4)),
          ],
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({required this.isOnline});
  final bool isOnline;

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
    if (!widget.isOnline) return Container(width: 8, height: 8, color: tokens.textDisabled);
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
