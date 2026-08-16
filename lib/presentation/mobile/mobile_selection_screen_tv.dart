// presentation/mobile/mobile_selection_screen_tv.dart
// ============================================================================
// STREAMZ — Mobile Interface Selection Gateway (NOC Dashboard)
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
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/noc_decorations.dart';

class MobileSelectionScreenTV extends StatefulWidget {
  const MobileSelectionScreenTV({super.key});

  @override
  State<MobileSelectionScreenTV> createState() => _MobileSelectionScreenTVState();
}

class _MobileSelectionScreenTVState extends State<MobileSelectionScreenTV> {
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: NocGridBackground(
              spacing: 60,
              color: tokens.borderSubtle,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, vm),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: DS.s80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: DS.s24),
                        Row(
                          children: [
                            Expanded(
                              child: _TVMobileModeCard(
                                label: 'MODERN UI',
                                subLabel: 'TOUCH-FRIENDLY DASHBOARD',
                                code: 'MOB-01',
                                icon: LucideIcons.tv,
                                onTap: () => context.push('/client/mobile/ui'),
                                autofocus: true,
                              ),
                            ),
                            const SizedBox(width: DS.s24),
                            Expanded(
                              child: _TVMobileModeCard(
                                label: 'FILE SYSTEM',
                                subLabel: 'RAW ASSET NAVIGATION',
                                code: 'MOB-02',
                                icon: LucideIcons.folderOpen,
                                onTap: () => context.push('/client/mobile/files'),
                              ),
                            ),
                            const SizedBox(width: DS.s24),
                            Expanded(
                              child: _TVMobileModeCard(
                                label: 'DISCONNECT',
                                subLabel: 'TERMINATE SESSION',
                                code: 'CMD-99',
                                icon: LucideIcons.power,
                                isWarning: true,
                                onTap: () {
                                  vm.disconnect();
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DS.s48),
                        Text(
                          'LIVE SIGNALS // DETECTED BROADCASTS',
                          style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 12, letterSpacing: 2),
                        ),
                        const SizedBox(height: DS.s16),
                        if (vm.stations.isEmpty)
                          _buildEmptySignals(context)
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 4,
                              crossAxisSpacing: DS.s24,
                              mainAxisSpacing: DS.s16,
                            ),
                            itemCount: vm.stations.length,
                            itemBuilder: (context, index) {
                              final station = vm.stations[index];
                              return _StationTileTV(
                                station: station,
                                onTap: () => _tuneIn(context, vm, station),
                              );
                            },
                          ),
                        const SizedBox(height: DS.s80),
                      ],
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

  Widget _buildHeader(BuildContext context, ClientViewModel vm) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s80, vertical: DS.s40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOBILE INTERFACE // SESSION ANALYSIS',
                  style: GoogleFonts.barlowCondensed(
                    color: tokens.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: DS.s8),
                Container(height: 2, width: 200, color: tokens.accent),
              ],
            ),
          ),
          const _StatusModule(label: 'ACTIVE MODE', value: 'MOBILE MODE'),
          const SizedBox(width: DS.s48),
          _StatusModule(label: 'HOST IP', value: vm.targetIp.toUpperCase()),
          const SizedBox(width: DS.s48),
          _StatusModule(label: 'ASSETS', value: '${vm.remoteMedia.length} INDEXED'),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s80, vertical: DS.s40),
      child: Row(
        children: [
          Text(
            'SIGNAL ANALYSIS: OPTIMAL // LATENCY: LOW // ENCRYPTION: NONE',
            style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 12, letterSpacing: 2),
          ),
          const Spacer(),
          const _BlinkingDotTV(),
        ],
      ),
    );
  }

  Widget _buildEmptySignals(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(DS.s48),
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.radioTower, size: 48, color: tokens.textMuted),
            const SizedBox(height: DS.s16),
            Text(
              'NO LIVE BROADCASTS DETECTED',
              style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 14, letterSpacing: 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusModule extends StatelessWidget {
  const _StatusModule({required this.label, required this.value});
  final String label;
  final String value;

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

class _TVMobileModeCard extends StatefulWidget {

  const _TVMobileModeCard({
    required this.label,
    required this.subLabel,
    required this.code,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
    this.isWarning = false,
  });
  final String label;
  final String subLabel;
  final String code;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;
  final bool isWarning;

  @override
  State<_TVMobileModeCard> createState() => _TVMobileModeCardState();
}

class _TVMobileModeCardState extends State<_TVMobileModeCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused ? tokens.surface3 : tokens.surface1;
    final borderColor = _isFocused ? (widget.isWarning ? tokens.error : tokens.accent) : tokens.border;

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
            height: 240,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: _isFocused ? 4 : 1),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: (widget.isWarning ? tokens.error : tokens.accent).withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: NocGridBackground(
                    spacing: 20,
                    color: _isFocused ? (widget.isWarning ? tokens.error : tokens.accent).withValues(alpha: 0.05) : tokens.borderSubtle,
                  ),
                ),
                _buildCorner(context, Alignment.topLeft, borderColor),
                _buildCorner(context, Alignment.topRight, borderColor),
                _buildCorner(context, Alignment.bottomLeft, borderColor),
                _buildCorner(context, Alignment.bottomRight, borderColor),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SYS_TYPE // ${widget.code}',
                        style: GoogleFonts.dmMono(
                          color: _isFocused ? tokens.textPrimary : tokens.textMuted,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: DS.s24),
                      Icon(
                        widget.icon,
                        color: _isFocused ? (widget.isWarning ? tokens.error : tokens.textPrimary) : tokens.textSecondary,
                        size: 48,
                      ),
                      const SizedBox(height: DS.s24),
                      Text(
                        widget.label,
                        style: GoogleFonts.barlowCondensed(
                          color: tokens.textPrimary,
                          fontSize: 28,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DS.s4),
                      Text(
                        widget.subLabel,
                        style: GoogleFonts.dmMono(
                          color: _isFocused ? tokens.textPrimary : tokens.textMuted,
                          fontSize: 11,
                          letterSpacing: 1,
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

  Widget _buildCorner(BuildContext context, Alignment alignment, Color color) => Align(
      alignment: alignment,
      child: Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight ? BorderSide(color: color, width: 2) : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? BorderSide(color: color, width: 2) : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? BorderSide(color: color, width: 2) : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? BorderSide(color: color, width: 2) : BorderSide.none,
          ),
        ),
      ),
    );
}

class _StationTileTV extends StatefulWidget {

  const _StationTileTV({required this.station, required this.onTap});
  final BroadcastStation station;
  final VoidCallback onTap;

  @override
  State<_StationTileTV> createState() => _StationTileTVState();
}

class _StationTileTVState extends State<_StationTileTV> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = widget.station.name.toUpperCase();
    final nowPlaying = widget.station.nowPlaying;
    final itemTitle = nowPlaying != null ? nowPlaying.item.title.toUpperCase() : 'AWAITING SIGNAL';

    return Focus(
      onFocusChange: (v) {
        setState(() => _isFocused = v);
        if (v) handleTVFocusScroll(v, context);
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _isFocused ? tokens.surface3 : tokens.surface1,
            border: Border.all(color: _isFocused ? tokens.accent : tokens.borderSubtle, width: _isFocused ? 2 : 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  border: Border.all(color: _isFocused ? tokens.accent : tokens.borderSubtle),
                ),
                child: Icon(LucideIcons.radio, color: _isFocused ? tokens.textPrimary : tokens.textSecondary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.barlowCondensed(
                        color: tokens.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'LIVE: $itemTitle',
                      style: GoogleFonts.dmMono(
                        color: _isFocused ? tokens.textPrimary : tokens.textMuted,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isFocused) Icon(LucideIcons.chevronRight, color: tokens.accent, size: 20),
            ],
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
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tokens.success,
              boxShadow: [BoxShadow(color: tokens.success, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'SIGNAL ESTABLISHED',
            style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}
