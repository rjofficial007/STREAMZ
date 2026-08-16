// presentation/client/client_connect_screen_tv.dart
// ============================================================================
// STREAMZ — TV Client Connection Screen (NOC Dashboard - V2)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/noc_decorations.dart';

class ClientConnectScreenTV extends StatefulWidget {
  const ClientConnectScreenTV({super.key});

  @override
  State<ClientConnectScreenTV> createState() => _ClientConnectScreenTVState();
}

class _ClientConnectScreenTVState extends State<ClientConnectScreenTV> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showManualInput = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientViewModel>().startDiscovery((ip) {
        if (mounted && _ctrl.text.isEmpty) {
          _ctrl.text = ip;
          _connect(ip);
        }
      });
    });
  }

  @override
  void dispose() {
    context.read<ClientViewModel>().stopDiscovery();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _connect([String? manualIp]) async {
    final ip = manualIp ?? _ctrl.text;
    if (ip.trim().isEmpty) return;
    
    // Stop discovery before connecting
    context.read<ClientViewModel>().stopDiscovery();

    final ok = await context.read<ClientViewModel>().connect(ip.trim());
    if (!mounted) return;

    if (ok) {
      if (mounted) context.pushReplacement('/client/interface');
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
          // Background Grid
          Positioned.fill(
            child: NocGridBackground(
              spacing: (size.width * 0.04).clamp(30.0, 60.0),
              color: tokens.borderSubtle,
            ),
          ),

          // Main Content
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
                        
                        // Integrated Manual IP Input OR Quick Actions
                        if (_showManualInput)
                          _buildIntegratedInput(context)
                        else
                          _buildQuickActions(vm),
                        
                        if (vm.connectionError != null)
                          _buildErrorBanner(context, vm.connectionError!),

                        SizedBox(height: (size.height * 0.05).clamp(24.0, 48.0)),
                        Text(
                          'RECENT NODES // ARCHIVED HANDSHAKES',
                          style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: (size.width * 0.008).clamp(9.0, 12.0), letterSpacing: 2),
                        ),
                        const SizedBox(height: DS.s16),
                        if (vm.ipHistory.isEmpty)
                          _buildEmptyHistory(context)
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
                            itemCount: vm.ipHistory.length,
                            itemBuilder: (context, index) {
                              final ip = vm.ipHistory[index];
                              return _HistoryTileTV(
                                ip: ip,
                                onTap: () => _connect(ip),
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

          // Loading Overlay
          if (vm.isLoading)
            Positioned.fill(
              child: Container(
                color: tokens.background.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: tokens.accent),
                      const SizedBox(height: 24),
                      Text(
                        'INITIATING HANDSHAKE...',
                        style: GoogleFonts.dmMono(color: tokens.accent, fontSize: 16, letterSpacing: 4, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntegratedInput(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);

    return Container(
      padding: EdgeInsets.all((size.width * 0.025).clamp(16.0, 32.0)),
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border.all(color: tokens.accent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MANUAL HANDSHAKE', style: GoogleFonts.dmMono(color: tokens.textSecondary, fontSize: (size.width * 0.009).clamp(10.0, 14.0), letterSpacing: 4)),
          SizedBox(height: (size.height * 0.03).clamp(16.0, 24.0)),
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (v) {
                    if (v) _focusNode.requestFocus();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _focusNode.hasFocus ? tokens.accent : tokens.borderStrong),
                      color: tokens.surface2,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: (size.width * 0.015).clamp(18.0, 24.0)),
                      decoration: InputDecoration(
                        hintText: 'ENTER IPv4 ADDRESS...',
                        hintStyle: TextStyle(color: tokens.textMuted),
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _connect(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _DialogBtn(
                label: 'INITIATE',
                isPrimary: true,
                onTap: _connect,
              ),
              const SizedBox(width: 16),
              _DialogBtn(
                label: 'CANCEL',
                onTap: () => setState(() => _showManualInput = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ClientViewModel vm) => Row(
      children: [
        Expanded(
          child: _TVConnectCard(
            label: 'MANUAL IP',
            subLabel: 'DIRECT NODE ADDRESSING',
            code: 'TCP-01',
            icon: LucideIcons.terminal,
            onTap: () {
              setState(() => _showManualInput = true);
              _focusNode.requestFocus();
            },
            autofocus: true,
          ),
        ),
        const SizedBox(width: DS.s24),
        Expanded(
          child: _TVConnectCard(
            label: vm.isDiscovering ? 'STOP SCAN' : 'DISCOVER',
            subLabel: 'AUTOMATIC NODE SEARCH',
            code: 'UDP-02',
            icon: vm.isDiscovering ? LucideIcons.searchX : LucideIcons.search,
            onTap: () => vm.isDiscovering ? vm.stopDiscovery() : vm.startDiscovery((_) {}),
          ),
        ),
      ],
    );

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
                  'CLIENT NODE // HANDSHAKE ANALYSIS',
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
          _StatusModule(label: 'SCAN STATUS', value: vm.isDiscovering ? 'ACTIVE' : 'IDLE'),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          _StatusModule(label: 'LAST NODE', value: vm.ipHistory.firstOrNull ?? 'NONE'),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          _StatusModule(label: 'HISTORY', value: '${vm.ipHistory.length} NODES'),
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
            'PROTOCOL: TCP/UDP // MODE: DISTRIBUTED // AUTH: TOKEN',
            style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: (size.width * 0.008).clamp(9.0, 12.0), letterSpacing: 2),
          ),
          const Spacer(),
          const _BlinkingDotTV(),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: DS.s24),
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: tokens.error.withValues(alpha: 0.1),
        border: Border.all(color: tokens.error),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertTriangle, color: tokens.error, size: 24),
          const SizedBox(width: DS.s16),
          Expanded(
            child: Text(
              'ERR: ${error.toUpperCase()}',
              style: GoogleFonts.dmMono(color: tokens.error, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory(BuildContext context) {
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
            Icon(LucideIcons.history, size: 48, color: tokens.textMuted),
            const SizedBox(height: DS.s16),
            Text(
              'NO ARCHIVED HANDSHAKES DETECTED',
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

class _TVConnectCard extends StatefulWidget {

  const _TVConnectCard({
    required this.label,
    required this.subLabel,
    required this.code,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
  });
  final String label;
  final String subLabel;
  final String code;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_TVConnectCard> createState() => _TVConnectCardState();
}

class _TVConnectCardState extends State<_TVConnectCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused ? tokens.surface3 : tokens.surface1;
    final borderColor = _isFocused ? tokens.accent : tokens.border;
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
                        color: tokens.accent.withValues(alpha: 0.2),
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
                    color: _isFocused ? tokens.accent.withValues(alpha: 0.05) : tokens.borderSubtle,
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
                        color: _isFocused ? tokens.textPrimary : tokens.textSecondary,
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

class _HistoryTileTV extends StatefulWidget {

  const _HistoryTileTV({required this.ip, required this.onTap});
  final String ip;
  final VoidCallback onTap;

  @override
  State<_HistoryTileTV> createState() => _HistoryTileTVState();
}

class _HistoryTileTVState extends State<_HistoryTileTV> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
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
                child: Icon(LucideIcons.hardDrive, color: _isFocused ? tokens.textPrimary : tokens.textSecondary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.ip.toUpperCase(),
                      style: GoogleFonts.barlowCondensed(
                        color: tokens.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'STATUS: ARCHIVED NODE',
                      style: GoogleFonts.dmMono(
                        color: _isFocused ? tokens.textPrimary : tokens.textMuted,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
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

class _DialogBtn extends StatefulWidget {

  const _DialogBtn({required this.label, required this.onTap, this.isPrimary = false});
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused ? tokens.accent : (widget.isPrimary ? tokens.surface4 : tokens.background);
    final textColor = _isFocused ? tokens.background : (widget.isPrimary ? tokens.textPrimary : tokens.textSecondary);

    return Focus(
      onFocusChange: (v) => setState(() => _isFocused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: tokens.accent),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.dmMono(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 2),
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
            'SYSTEM SCANNING',
            style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}
