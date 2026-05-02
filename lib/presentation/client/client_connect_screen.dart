// presentation/client/client_connect_screen.dart
// ============================================================================
// STREAMZ — Client Connection Screen
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mobile/mobile_selection_screen.dart';
import '../tv/tv_selection_screen.dart';
import 'client_viewmodel.dart';
import 'qr_scanner_screen.dart';

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

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    context.read<ClientViewModel>().stopDiscovery();

    final ok = await context.read<ClientViewModel>().connect(_ctrl.text);
    if (!mounted) return;

    if (ok) {
      final isTV = MediaQuery.sizeOf(context).width >= DS.bpTV;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
              value: context.read<ClientViewModel>(),
              child: isTV ? const TVSelectionScreen() : const MobileSelectionScreen()
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final isMobile = DS.isMobile(context);
    final hPad = DS.hPad(MediaQuery.sizeOf(context).width);

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: DS.bg,
        leading: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
              Navigator.pop(context);
              return null;
            }),
          },
          child: Focus(
            onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => Navigator.pop(context)),
            child: IconButton(
              icon: Icon(PhosphorIconsRegular.arrowLeft, size: isMobile ? 20 : 24),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'CLIENT NODE',
          style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ),
      body: Stack(
        children: [
          // Background grid
          Positioned.fill(
            child: Opacity(opacity: 0.12, child: const CustomPaint(painter: GridPainter())),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: isMobile ? 24 : 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero title
                      Text('CONNECT', style: AppTheme.theme.textTheme.displayLarge?.copyWith(fontSize: isMobile ? 48 : 72, height: 1.0)),
                      const SizedBox(height: DS.s12),
                      Text(
                        'ENTER IPv4 OR SCAN QR TO INITIATE HANDSHAKE',
                        style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: isMobile ? 11 : 13, color: DS.textMuted),
                      ),
                      SizedBox(height: isMobile ? DS.s32 : DS.s48),

                      // Discovery banner
                      if (vm.isDiscovering) ...[
                        Container(
                          padding: EdgeInsets.all(isMobile ? DS.s16 : DS.s24),
                          decoration: BoxDecoration(
                            color: DS.surface1,
                            border: Border.all(color: DS.accent, width: 2),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: isMobile ? 16 : 20,
                                height: isMobile ? 16 : 20,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: DS.accent),
                              ),
                              SizedBox(width: isMobile ? DS.s16 : DS.s24),
                              Expanded(
                                child: Text('SCANNING LOCAL NETWORK...', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 11 : 13)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? DS.s16 : DS.s24),
                      ],

                      // IP history chips (TV Compliant)
                      if (vm.ipHistory.isNotEmpty) ...[
                        Text('RECENT CONNECTIONS', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
                        const SizedBox(height: DS.s8),
                        Wrap(
                          spacing: DS.s8,
                          runSpacing: DS.s8,
                          children: vm.ipHistory
                              .map(
                                (ip) => _RecentIpChip(
                              ip: ip,
                              onTap: () {
                                _ctrl.text = ip;
                                _connect();
                              },
                            ),
                          )
                              .toList(),
                        ),
                        SizedBox(height: isMobile ? DS.s16 : DS.s24),
                      ],

                      // Input form
                      BrutalistBlock(
                        padding: EdgeInsets.all(isMobile ? DS.s24 : DS.s32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SERVER IPv4 ADDRESS', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: isMobile ? 10 : 12)),
                            const SizedBox(height: DS.s12),
                            Container(
                              height: isMobile ? 48 : 56,
                              decoration: BoxDecoration(
                                color: DS.bg,
                                border: Border.all(color: DS.borderDefault),
                              ),
                              child: TextField(
                                controller: _ctrl,
                                style: GoogleFonts.dmMono(color: Colors.white, fontSize: isMobile ? 14 : 16, letterSpacing: 1.5),
                                decoration: const InputDecoration(
                                  hintText: '192.168.1.X',
                                  hintStyle: TextStyle(color: Colors.white24),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                keyboardType: TextInputType.number,
                                onSubmitted: (_) => _connect(),
                              ),
                            ),
                            SizedBox(height: isMobile ? DS.s24 : DS.s32),
                            CompactBtn(label: 'CONNECT TO HOST', isLoading: vm.isLoading, height: isMobile ? 48 : 56, onTap: _connect),
                            SizedBox(height: isMobile ? DS.s24 : DS.s32),
                            Row(
                              children: [
                                const Expanded(child: Divider(color: DS.borderDefault)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: DS.s16),
                                  child: Text('OR', style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.textMuted)),
                                ),
                                const Expanded(child: Divider(color: DS.borderDefault)),
                              ],
                            ),
                            SizedBox(height: isMobile ? DS.s24 : DS.s32),
                            CompactBtn(
                              label: 'SCAN QR CODE',
                              icon: PhosphorIconsRegular.qrCode,
                              isPrimary: false,
                              height: isMobile ? 48 : 56,
                              onTap: () async {
                                if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'QR scanning is only available on mobile.',
                                        style: TextStyle(fontFamily: 'DM Mono', color: Colors.black),
                                      ),
                                      backgroundColor: DS.accent,
                                    ),
                                  );
                                  return;
                                }
                                final ip = await Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerScreen()));
                                if (ip is String && mounted) {
                                  _ctrl.text = ip;
                                  _connect();
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // Error
                      if (vm.connectionError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: DS.s24),
                          child: Container(
                            padding: const EdgeInsets.all(DS.s16),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Row(
                              children: [
                                const Icon(PhosphorIconsRegular.warningOctagon, color: Colors.redAccent, size: 20),
                                const SizedBox(width: DS.s16),
                                Expanded(
                                  child: Text(
                                    'ERR: ${vm.connectionError!}',
                                    style: GoogleFonts.dmMono(color: Colors.redAccent, fontSize: isMobile ? 11 : 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT IP CHIP (TV Compliant)
// ─────────────────────────────────────────────────────────────────────────────

class _RecentIpChip extends StatefulWidget {
  final String ip;
  final VoidCallback onTap;

  const _RecentIpChip({required this.ip, required this.onTap});

  @override
  State<_RecentIpChip> createState() => _RecentIpChipState();
}

class _RecentIpChipState extends State<_RecentIpChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: Focus(
        onFocusChange: (val) {
          setState(() => _isFocused = val);
          handleTVFocusScroll(val, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: DS.s8),
            decoration: BoxDecoration(
              color: _isFocused ? DS.surface3 : Colors.transparent,
              border: Border.all(color: _isFocused ? DS.accent : DS.borderDefault, width: _isFocused ? 2 : 1),
              boxShadow: _isFocused ? [const BoxShadow(color: DS.accent, offset: Offset(2, 2))] : [],
            ),
            child: Text(
                widget.ip,
                style: GoogleFonts.dmMono(color: _isFocused ? DS.accent : DS.textSecondary, fontSize: 11, letterSpacing: 1, fontWeight: _isFocused ? FontWeight.bold : FontWeight.normal)
            ),
          ),
        ),
      ),
    );
  }
}