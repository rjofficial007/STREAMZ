// presentation/client/client_connect_screen.dart
// ============================================================================
// STREAMZ — Client Connection Screen (Samsung-Style / Brutalist Edition)
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'client_viewmodel.dart';
import 'client_connect_screen_tv.dart';
import 'interface_selection_screen.dart';
import 'qr_scanner_screen.dart';

// --- Web UI Color Palette & Styles (Synced with Server Dashboard) ---
const Color kWebBlack = Color(0xFF000000);
const Color kWebSurface = Color(0xFF0A0A0A);
const Color kWebSurface2 = Color(0xFF111111);
const Color kWebWhite = Color(0xFFFFFFFF);
final Color kWebBorder = Colors.white.withValues(alpha: 0.15);
final Color kWebTextMuted = Colors.white.withValues(alpha: 0.3);
final Color kWebText = Colors.white.withValues(alpha: 0.6);

class ClientConnectScreen extends StatefulWidget {
  const ClientConnectScreen({super.key});

  @override
  State<ClientConnectScreen> createState() => _ClientConnectScreenState();
}

class _ClientConnectScreenState extends State<ClientConnectScreen> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientViewModel>().startDiscovery((ip) {
        if (mounted && _ctrl.text.isEmpty) {
          _ctrl.text = ip;
          _connect();
        }
      });
    });
  }

  @override
  void dispose() {
    context.read<ClientViewModel>().stopDiscovery();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _connect([String? manualIp]) async {
    final ip = manualIp ?? _ctrl.text;
    if (ip.isEmpty) return;
    
    FocusScope.of(context).unfocus();
    context.read<ClientViewModel>().stopDiscovery();

    final ok = await context.read<ClientViewModel>().connect(ip);
    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<ClientViewModel>(), 
            child: const InterfaceSelectionScreen()
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (DS.isTV(context)) {
      return const ClientConnectScreenTV();
    }

    final vm = context.watch<ClientViewModel>();

    return Scaffold(
      backgroundColor: kWebBlack,
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
        'CLIENT NODE',
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

  Widget _buildBody(ClientViewModel vm) {
    return SliverList(
      delegate: SliverChildListDelegate([
        _HandshakeAnalysisCard(vm: vm),
        
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
                onTap: () => vm.isDiscovering ? vm.stopDiscovery() : vm.startDiscovery((_) {}),
              ),
            ],
          ),
        ),

        if (vm.connectionError != null)
          _ErrorBanner(error: vm.connectionError!),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('RECENT NODES', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
        ),
        
        if (vm.ipHistory.isEmpty)
          _EmptyHistoryPlaceholder()
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

  void _scanQR() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR SCAN ONLY AVAILABLE ON MOBILE', style: GoogleFonts.dmMono(color: kWebBlack, fontWeight: FontWeight.bold)),
          backgroundColor: kWebWhite,
        ),
      );
      return;
    }
    final ip = await Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerScreen()));
    if (ip is String && mounted) {
      _ctrl.text = ip;
      _connect();
    }
  }

  void _showManualIpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWebBlack,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: kWebBorder))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MANUAL HANDSHAKE', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 12, letterSpacing: 4)),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(border: Border.all(color: kWebBorder)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: GoogleFonts.dmMono(color: kWebWhite),
                  decoration: InputDecoration(
                    hintText: 'ENTER IPv4...',
                    hintStyle: TextStyle(color: kWebTextMuted),
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) {
                    Navigator.pop(ctx);
                    _connect();
                  },
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _connect();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: kWebWhite),
                  child: Center(
                    child: Text('INITIATE CONNECTION', style: GoogleFonts.dmMono(color: kWebBlack, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
  final ClientViewModel vm;
  const _HandshakeAnalysisCard({required this.vm});

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
              Text('HANDSHAKE ANALYSIS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                    Text('SCAN STATUS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(vm.isDiscovering ? 'ACTIVE' : 'IDLE', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('LAST NODE', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(vm.ipHistory.firstOrNull ?? 'NONE', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(height: 8, color: kWebSurface2),
              if (vm.isDiscovering)
                _DiscoveryProgressBar(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _legend('HISTORY', '${vm.ipHistory.length} NODES', kWebWhite)),
              const SizedBox(width: 16),
              Expanded(child: _legend('NETWORK', 'READY', Colors.white70)),
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => FractionallySizedBox(
        widthFactor: _ctrl.value,
        child: Container(height: 8, color: kWebWhite),
      ),
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

class _HistoryTile extends StatefulWidget {
  final String ip;
  final bool isFirst;
  final VoidCallback onTap;

  const _HistoryTile({required this.ip, required this.isFirst, required this.onTap});

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
              child: Icon(LucideIcons.hardDrive, color: kWebText, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ip.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 3),
                  Text('STATUS: ARCHIVED NODE', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 9, letterSpacing: 1)),
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

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'ERR: ${error.toUpperCase()}',
              style: GoogleFonts.dmMono(color: Colors.redAccent, fontSize: 11),
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
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: kWebBorder))),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.history, size: 40, color: kWebTextMuted),
            const SizedBox(height: 12),
            Text('NO HISTORY DETECTED', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 4)),
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
