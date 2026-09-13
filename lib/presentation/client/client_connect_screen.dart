// presentation/client/client_connect_screen.dart
// ============================================================================
// STREAMZ — Client Connection Screen (Samsung-Style / Brutalist Edition)
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/client/client_connect_screen_tv.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';

class ClientConnectScreen extends StatefulWidget {
  const ClientConnectScreen({super.key});

  @override
  State<ClientConnectScreen> createState() => _ClientConnectScreenState();
}

class _ClientConnectScreenState extends State<ClientConnectScreen> {
  final _ctrl = TextEditingController();
  // [SECURITY B1] Optional pairing-code field (manual handshake).
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientViewModel>().startDiscovery((ip, token) {
        if (mounted && _ctrl.text.isEmpty) {
          _ctrl.text = ip;
          unawaited(_connect(ip, token));
        }
      });
    });
  }

  @override
  void dispose() {
    context.read<ClientViewModel>().stopDiscovery();
    _ctrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect([String? manualIp, String? pairingToken]) async {
    final ip = (manualIp ?? _ctrl.text).trim();
    if (ip.isEmpty) return;
    // Explicit token (QR/discovery) wins; otherwise fall back to the field.
    final code = (pairingToken ?? _codeCtrl.text).trim();

    FocusScope.of(context).unfocus();
    context.read<ClientViewModel>().stopDiscovery();

    final ok = await context.read<ClientViewModel>().connect(
      ip,
      pairingToken: code.isEmpty ? null : code,
    );
    if (!mounted) return;

    if (ok) {
      if (mounted) context.pushReplacement('/client/interface');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (DS.isTV(context)) {
      return const ClientConnectScreenTV();
    }

    final vm = context.watch<ClientViewModel>();
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            _buildBody(vm),
          ],
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
      titleSpacing: 0,
      leading: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              context.pop();
              return null;
            },
          ),
        },
        child: Focus(
          onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => context.pop()),
          child: IconButton(
            tooltip: 'BACK',
            icon: Icon(LucideIcons.chevronLeft, size: 20, color: tokens.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      title: Text(
        'CLIENT NODE',
        style: GoogleFonts.barlowCondensed(
          color: tokens.textPrimary, 
          fontSize: 20, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 4
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
      ),
    );
  }

  Widget _buildBody(ClientViewModel vm) {
    final tokens = context.tokens;
    return SliverList(
      delegate: SliverChildListDelegate([
        _HandshakeAnalysisCard(vm: vm),
        
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))), 
            color: tokens.border.withValues(alpha: 0.15)
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
                label: 'SCAN QR',
                icon: LucideIcons.qrCode,
                onTap: _scanQR,
              ),
              _QuickActionCard(
                label: 'MANUAL IP',
                icon: LucideIcons.terminal,
                onTap: _showManualIpSheet,
              ),
              _QuickActionCard(
                label: vm.isDiscovering ? 'STOP SCAN' : 'DISCOVER',
                icon: vm.isDiscovering ? LucideIcons.searchX : LucideIcons.search,
                onTap: () => vm.isDiscovering ? vm.stopDiscovery() : vm.startDiscovery((ip, token) {}),
              ),
            ],
          ),
        ),

        if (vm.connectionError != null)
          _ErrorBanner(error: vm.connectionError!),

        // [SECURITY B1] Media may still load over HTTP — the banner explains
        // why live control (WS) is unavailable.
        if (vm.wsAuthError != null)
          _ErrorBanner(error: vm.wsAuthError!),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('RECENT NODES', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 2)),
        ),
        
        if (vm.ipHistory.isEmpty)
          const _EmptyHistoryPlaceholder()
        else
          ...vm.ipHistory.asMap().entries.map((e) => _HistoryTile(
            ip: e.value, 
            isFirst: e.key == 0, 
            onTap: () => _connect(e.value),
          )),
          
        const SizedBox(height: 100),
      ]),
    );
  }

  Future<void> _scanQR() async {
    final tokens = context.tokens;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR SCAN ONLY AVAILABLE ON MOBILE', style: GoogleFonts.dmMono(color: tokens.background, fontWeight: FontWeight.bold)),
          backgroundColor: tokens.textPrimary,
        ),
      );
      return;
    }
    final raw = await context.push<String>('/qr-scanner');
    if (raw == null || !mounted) return;
    // [SECURITY B1] New QRs encode http://<ip>:8080/?token=<code>;
    // legacy QRs are a bare IP (control plane will prompt for the code).
    final uri = Uri.tryParse(raw.trim());
    if (uri != null && uri.host.isNotEmpty) {
      _ctrl.text = uri.host;
      unawaited(_connect(uri.host, uri.queryParameters['token']));
    } else {
      _ctrl.text = raw.trim();
      unawaited(_connect(raw.trim()));
    }
  }

  void _showManualIpSheet() {
    final tokens = context.tokens;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MANUAL HANDSHAKE', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 12, letterSpacing: 4)),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15))),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: GoogleFonts.dmMono(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'ENTER IPv4...',
                    hintStyle: TextStyle(color: tokens.textMuted),
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) {
                    context.pop();
                    _connect();
                  },
                ),
              ),
              const SizedBox(height: 8),
              // [SECURITY B1] Optional pairing code for the WS control plane
              // (shown on the server's QR sheet).
              Container(
                decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15))),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _codeCtrl,
                  style: GoogleFonts.dmMono(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'PAIRING CODE (OPTIONAL)...',
                    hintStyle: TextStyle(color: tokens.textMuted),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) {
                    context.pop();
                    _connect();
                  },
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  context.pop();
                  _connect();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: tokens.textPrimary),
                  child: Center(
                    child: Text('INITIATE CONNECTION', style: GoogleFonts.dmMono(color: tokens.background, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandshakeAnalysisCard extends StatelessWidget {
  const _HandshakeAnalysisCard({required this.vm});
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
              Text('HANDSHAKE ANALYSIS', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              _BlinkingDot(isOnline: vm.isDiscovering),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SCAN STATUS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(vm.isDiscovering ? 'ACTIVE' : 'IDLE', style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('LAST NODE', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(vm.ipHistory.firstOrNull ?? 'NONE', style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(height: 8, color: tokens.surface2),
              if (vm.isDiscovering)
                const _DiscoveryProgressBar(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _legend(context, 'HISTORY', '${vm.ipHistory.length} NODES', tokens.textPrimary)),
              const SizedBox(width: 16),
              Expanded(child: _legend(context, 'NETWORK', 'READY', tokens.textSecondary)),
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

class _DiscoveryProgressBar extends StatefulWidget {
  const _DiscoveryProgressBar();

  @override
  State<_DiscoveryProgressBar> createState() => _DiscoveryProgressBarState();
}

class _DiscoveryProgressBarState extends State<_DiscoveryProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => FractionallySizedBox(
        widthFactor: _ctrl.value,
        child: Container(height: 8, color: tokens.accent),
      ),
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        color: _isPressed ? tokens.textPrimary.withValues(alpha: 0.1) : tokens.surface2,
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
    );
  }
}

class _HistoryTile extends StatefulWidget {

  const _HistoryTile({required this.ip, required this.isFirst, required this.onTap});
  final String ip;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
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
              child: Icon(LucideIcons.hardDrive, color: tokens.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ip.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 3),
                  Text('STATUS: ARCHIVED NODE', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 1)),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.error.withValues(alpha: 0.1),
        border: Border.all(color: tokens.error),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertTriangle, color: tokens.error, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'ERR: ${error.toUpperCase()}',
              style: GoogleFonts.dmMono(color: tokens.error, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryPlaceholder extends StatelessWidget {
  const _EmptyHistoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.history, size: 40, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text('NO HISTORY DETECTED', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 4)),
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
