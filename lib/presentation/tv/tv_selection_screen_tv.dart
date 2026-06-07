// presentation/tv/tv_selection_screen_tv.dart
// ============================================================================
// STREAMZ — TV Interface Selection Gateway (NOC Dashboard)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../shared/noc_decorations.dart';
import '../client/client_viewmodel.dart';
import '../player/player_screen.dart';
import '../../domain/models/media_item.dart';
import 'tv_file_manager.dart';
import 'tv_home_screen.dart';

class TVSelectionScreenTV extends StatefulWidget {
  const TVSelectionScreenTV({super.key});

  @override
  State<TVSelectionScreenTV> createState() => _TVSelectionScreenTVState();
}

class _TVSelectionScreenTVState extends State<TVSelectionScreenTV> {
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);

    return Scaffold(
      backgroundColor: tokens.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: NocGridBackground(
              spacing: (size.width * 0.04).clamp(30.0, 60.0),
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
                    padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: DS.s24),
                        Row(
                          children: [
                            Expanded(
                              child: _TVModeCard(
                                label: 'MODERN UI',
                                subLabel: 'LARGE SCREEN DASHBOARD',
                                code: 'TV-01',
                                icon: LucideIcons.tv,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChangeNotifierProvider.value(value: vm, child: const TVHomeScreen()),
                                  ),
                                ),
                                autofocus: true,
                              ),
                            ),
                            const SizedBox(width: DS.s24),
                            Expanded(
                              child: _TVModeCard(
                                label: 'FILE SYSTEM',
                                subLabel: 'RAW ASSET NAVIGATION',
                                code: 'TV-02',
                                icon: LucideIcons.folderOpen,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChangeNotifierProvider.value(value: vm, child: const TVFileManagerScreen()),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: DS.s24),
                            Expanded(
                              child: _TVModeCard(
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
                        SizedBox(height: (size.height * 0.05).clamp(24.0, 48.0)),
                        Text(
                          'LIVE SIGNALS // DETECTED BROADCASTS',
                          style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: (size.width * 0.008).clamp(9.0, 12.0), letterSpacing: 2),
                        ),
                        const SizedBox(height: DS.s16),
                        if (vm.stations.isEmpty)
                          _buildEmptySignals(context)
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: size.width > 1200 ? 2 : 1,
                              childAspectRatio: size.width > 1200 ? 4 : 5,
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
                  'TV INTERFACE // SESSION ANALYSIS',
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
          _StatusModule(label: 'ACTIVE MODE', value: 'TV MODE'),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          _StatusModule(label: 'HOST IP', value: vm.targetIp.toUpperCase()),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          _StatusModule(label: 'ASSETS', value: '${vm.remoteMedia.length} INDEXED'),
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
            'SIGNAL ANALYSIS: OPTIMAL // LATENCY: LOW // ENCRYPTION: NONE',
            style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: (size.width * 0.008).clamp(9.0, 12.0), letterSpacing: 2),
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

class _TVModeCard extends StatefulWidget {
  final String label;
  final String subLabel;
  final String code;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;
  final bool isWarning;

  const _TVModeCard({
    required this.label,
    required this.subLabel,
    required this.code,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
    this.isWarning = false,
  });

  @override
  State<_TVModeCard> createState() => _TVModeCardState();
}

class _TVModeCardState extends State<_TVModeCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused ? tokens.surface3 : tokens.surface1;
    final borderColor = _isFocused ? (widget.isWarning ? tokens.error : tokens.accent) : tokens.border;
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
            height: (size.height * 0.3).clamp(180.0, 300.0),
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
                          fontSize: (size.width * 0.008).clamp(9.0, 12.0),
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: (size.height * 0.02).clamp(12.0, 24.0)),
                      Icon(
                        widget.icon,
                        color: _isFocused ? (widget.isWarning ? tokens.error : tokens.textPrimary) : tokens.textSecondary,
                        size: (size.width * 0.035).clamp(32.0, 56.0),
                      ),
                      SizedBox(height: (size.height * 0.02).clamp(12.0, 24.0)),
                      Text(
                        widget.label,
                        style: GoogleFonts.barlowCondensed(
                          color: tokens.textPrimary,
                          fontSize: (size.width * 0.018).clamp(20.0, 32.0),
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
                          fontSize: (size.width * 0.008).clamp(9.0, 12.0),
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

  Widget _buildCorner(BuildContext context, Alignment alignment, Color color) {
    return Align(
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
}

class _StationTileTV extends StatefulWidget {
  final Map<String, dynamic> station;
  final VoidCallback onTap;

  const _StationTileTV({required this.station, required this.onTap});

  @override
  State<_StationTileTV> createState() => _StationTileTVState();
}

class _StationTileTVState extends State<_StationTileTV> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = widget.station['name'].toString().toUpperCase();
    final nowPlaying = widget.station['nowPlaying'];
    final itemTitle = nowPlaying != null ? nowPlaying['item']['title'].toString().toUpperCase() : 'AWAITING SIGNAL';

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
