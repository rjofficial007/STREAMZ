// presentation/server/server_dashboard.dart
// ============================================================================
// STREAMZ — Server NOC Dashboard (Brutalist Web Studio Edition)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/network/http_server.dart';
import '../../domain/models/connection_record.dart';
import '../../domain/models/stream_session.dart';
import '../../domain/models/broadcast_station.dart';
import '../../domain/models/media_item.dart';
import '../../domain/services/station_service.dart';
import '../client/client_viewmodel.dart';
import '../mobile/mobile_selection_screen.dart';
import '../tv/tv_selection_screen.dart';
import 'server_viewmodel.dart';

// --- Web UI Color Palette & Styles ---
const Color kWebBlack = Color(0xFF000000);
const Color kWebSurface = Color(0xFF0A0A0A);
const Color kWebSurface2 = Color(0xFF111111);
const Color kWebWhite = Color(0xFFFFFFFF);
final Color kWebBorder = Colors.white.withValues(alpha: 0.15);
final Color kWebTextMuted = Colors.white.withValues(alpha: 0.3);
final Color kWebText = Colors.white.withValues(alpha: 0.6);

class ServerDashboard extends StatefulWidget {
  const ServerDashboard({super.key});

  @override
  State<ServerDashboard> createState() => _ServerDashboardState();
}

class _ServerDashboardState extends State<ServerDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServerViewModel>().startServer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerViewModel>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: kWebBlack,
        body: Stack(
          children: [
            Positioned.fill(
              child: Opacity(opacity: 0.05, child: const CustomPaint(painter: GridPainter())),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isDesktop = width > DS.bpTablet;
                  final isMobile = width <= DS.bpMobile;
                  final pad = isDesktop ? 48.0 : (isMobile ? 16.0 : 32.0);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.fromLTRB(pad, isMobile ? 16 : 24, pad, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Actions(
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
                                      icon: Icon(LucideIcons.arrowLeft, size: isMobile ? 18 : 20, color: kWebWhite),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'NODE // BROADCAST',
                                    style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: isMobile ? 10 : 12, letterSpacing: 4),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  'SERVER',
                                  style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: isMobile ? 48 : 72, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: 2)
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 16 : 24),

                      // Tab bar
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: kWebBorder)),
                          child: TabBar(
                            isScrollable: false,
                            indicator: const BoxDecoration(color: kWebWhite),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: kWebBlack,
                            unselectedLabelColor: kWebTextMuted,
                            labelStyle: GoogleFonts.dmMono(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: isMobile ? 10 : 13),
                            tabs: const [
                              Tab(text: 'ACTIVITY'),
                              Tab(text: 'NETWORK'),
                              Tab(text: 'SHARING'),
                              Tab(text: 'STATIONS'),
                            ],
                          ),
                        ),
                      ),

                      Expanded(
                        child: TabBarView(
                          children: [
                            _ActivityTab(state: state, pad: pad, isMobile: isMobile, isDesktop: isDesktop),
                            _NetworkTab(state: state, pad: pad, isMobile: isMobile),
                            _SharingTab(state: state, pad: pad, isMobile: isMobile),
                            _StationsTab(state: state, pad: pad, isMobile: isMobile),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  final ServerViewModel state;
  final double pad;
  final bool isMobile;
  final bool isDesktop;

  const _ActivityTab({required this.state, required this.pad, required this.isMobile, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 24, pad, 40),
      child: isDesktop
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _CoreCard(state: state, isMobile: isMobile),
                const SizedBox(height: 24),
                _MetricsRow(state: state, isMobile: isMobile),
                const SizedBox(height: 24),
                _QRCard(state: state, isMobile: isMobile),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: _TelemetryCard(state: state, isMobile: isMobile),
          ),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CoreCard(state: state, isMobile: isMobile),
          const SizedBox(height: 16),
          _MetricsRow(state: state, isMobile: isMobile),
          const SizedBox(height: 16),
          _QRCard(state: state, isMobile: isMobile),
          const SizedBox(height: 24),
          _TelemetryCard(state: state, isMobile: isMobile),
        ],
      ),
    );
  }
}

class _CoreCard extends StatefulWidget {
  final ServerViewModel state;
  final bool isMobile;
  const _CoreCard({required this.state, required this.isMobile});

  @override
  State<_CoreCard> createState() => _CoreCardState();
}

class _CoreCardState extends State<_CoreCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kWebBorder),
        color: kWebSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TerminalHeader(title: 'CORE ENGINE', icon: LucideIcons.cpu),
          Padding(
            padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('IPv4 BROADCAST', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
                    Row(
                      children: [
                        _BlinkingDot(isOnline: widget.state.isRunning),
                        const SizedBox(width: 8),
                        Text(
                          widget.state.isRunning ? 'ONLINE' : 'OFFLINE',
                          style: GoogleFonts.dmMono(color: widget.state.isRunning ? kWebWhite : kWebTextMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: 'http://${widget.state.serverIp}:8080'));
                    HapticFeedback.lightImpact();
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.state.serverIp == 'No Network' || widget.state.serverIp == 'Initializing...' ? widget.state.serverIp.toUpperCase() : 'HTTP://${widget.state.serverIp}:8080',
                      style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: kWebBorder),
          Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  if (!widget.state.isInitializing) widget.state.isRunning ? widget.state.stopServer() : widget.state.startServer();
                  return null;
                },
              ),
            },
            child: Focus(
              onFocusChange: (v) {
                setState(() => _isFocused = v);
                handleTVFocusScroll(v, context);
              },
              onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.state.isInitializing ? null : () => widget.state.isRunning ? widget.state.stopServer() : widget.state.startServer()),
              child: GestureDetector(
                onTap: widget.state.isInitializing
                    ? null
                    : () {
                  HapticFeedback.mediumImpact();
                  widget.state.isRunning ? widget.state.stopServer() : widget.state.startServer();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(vertical: widget.isMobile ? 16 : 20),
                  color: widget.state.isInitializing ? kWebSurface2 : (_isFocused ? kWebWhite : (widget.state.isRunning ? kWebWhite : kWebSurface)),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.state.isInitializing ? 'BOOTING...' : (widget.state.isRunning ? 'STOP ENGINE' : 'START ENGINE'),
                          style: GoogleFonts.barlowCondensed(
                            color: widget.state.isInitializing ? kWebTextMuted : (_isFocused ? kWebBlack : (widget.state.isRunning ? kWebBlack : kWebWhite)),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: widget.isMobile ? 24 : 48,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
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

class _MetricsRow extends StatelessWidget {
  final ServerViewModel state;
  final bool isMobile;
  const _MetricsRow({required this.state, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(label: 'CONNECTED NODES', value: '${state.connectedClients}', isMobile: isMobile),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatBox(label: 'OUTBOUND DATA', value: state.currentSpeedMb.toStringAsFixed(1), unit: 'MB/S', isMobile: isMobile),
        ),
      ],
    );
  }
}

class _QRCard extends StatelessWidget {
  final ServerViewModel state;
  final bool isMobile;
  const _QRCard({required this.state, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kWebBorder),
        color: kWebSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TerminalHeader(title: 'QUICK PAIRING', icon: LucideIcons.qrCode),
          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            child: Column(
              children: [
                Container(
                  width: isMobile ? 160 : 200,
                  height: isMobile ? 160 : 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: kWebWhite, width: 1)),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(data: state.serverIp, version: QrVersions.auto, backgroundColor: Colors.white),
                  ),
                ),
                SizedBox(height: isMobile ? 24 : 32),
                Text('SCAN TO INITIATE HANDSHAKE', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2), textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  final ServerViewModel state;
  final bool isMobile;
  const _TelemetryCard({required this.state, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final sessions = state.activeSessions;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kWebBorder),
        color: kWebSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TerminalHeader(title: 'LIVE TELEMETRY FEED', icon: LucideIcons.activity),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(LucideIcons.wifiHigh, size: 48, color: kWebTextMuted),
                    const SizedBox(height: 16),
                    Text('NO SIGNAL DETECTED', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 12, letterSpacing: 4)),
                  ],
                ),
              ),
            )
          else
            ...sessions.map((s) => _TelemetryRow(session: s, isMobile: isMobile)),
        ],
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  final StreamSession session;
  final bool isMobile;
  const _TelemetryRow({required this.session, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    Color badgeBg = kWebWhite;
    Color badgeFg = kWebBlack;
    String badge = 'STR';

    if (session.mediaType == 'video') {
      badge = 'VID';
    } else if (session.mediaType == 'audio') {
      badge = 'AUD';
    } else if (session.mediaType == 'download') {
      badge = 'DWN';
      badgeBg = kWebSurface2;
      badgeFg = kWebWhite;
    }

    final safeProgress = session.progress.isFinite ? session.progress.clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kWebBorder)),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: badgeBg,
                child: Text(
                  badge,
                  style: GoogleFonts.dmMono(color: badgeFg, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title.toUpperCase(),
                      style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('NODE_ID : ${session.clientId.toUpperCase()}', style: GoogleFonts.dmMono(fontSize: 9, color: kWebTextMuted, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          if (safeProgress > 0) ...[
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(height: 2, color: kWebSurface2),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: safeProgress,
                  child: Container(
                    height: 2,
                    color: kWebWhite,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NETWORK TAB
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkTab extends StatelessWidget {
  final ServerViewModel state;
  final double pad;
  final bool isMobile;
  const _NetworkTab({required this.state, required this.pad, required this.isMobile});

  Future<void> _safePreview(BuildContext context, bool isTV) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: kWebWhite)),
    );
    final vm = ClientViewModel();
    final ok = await vm.connect(state.serverIp);
    if (context.mounted) Navigator.pop(context);
    if (ok && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(value: vm, child: isTV ? const TVSelectionScreen() : const MobileSelectionScreen()),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PREVIEW CONNECTION FAILED', style: GoogleFonts.dmMono(color: kWebWhite)), backgroundColor: kWebSurface2));
    }
  }

  void _showStartEngineWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'START ENGINE FIRST',
          style: GoogleFonts.dmMono(color: kWebBlack, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kWebWhite,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 24, pad, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: kWebBorder),
              color: kWebSurface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TerminalHeader(title: 'SYSTEM UTILITIES', icon: LucideIcons.terminal),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: LucideIcons.globe,
                        title: 'WEB UI',
                        meta: 'PORT 8080',
                        isRightBorder: true,
                        isBottomBorder: true,
                        onTap: () => launchUrl(Uri.parse('http://${state.serverIp}:8080')),
                      ),
                    ),
                    Expanded(
                      child: _ActionCard(
                        icon: LucideIcons.history,
                        title: 'LOGS',
                        meta: 'HISTORY',
                        isBottomBorder: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _ConnectionHistoryScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: LucideIcons.smartphone,
                        title: 'PREVIEW MOBILE',
                        meta: state.isRunning ? 'LOCAL UI' : 'OFFLINE',
                        isActive: state.isRunning,
                        isRightBorder: true,
                        isBottomBorder: true,
                        onTap: state.isRunning ? () => _safePreview(context, false) : () => _showStartEngineWarning(context),
                      ),
                    ),
                    Expanded(
                      child: _ActionCard(
                        icon: LucideIcons.tv,
                        title: 'PREVIEW TV',
                        meta: state.isRunning ? '10-FOOT UI' : 'OFFLINE',
                        isActive: state.isRunning,
                        isBottomBorder: true,
                        onTap: state.isRunning ? () => _safePreview(context, true) : () => _showStartEngineWarning(context),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: LucideIcons.share2,
                        title: 'SHARE',
                        meta: 'COPY LINK',
                        isRightBorder: true,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: 'http://${state.serverIp}:8080'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'LINK COPIED',
                                style: GoogleFonts.dmMono(color: kWebBlack, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: kWebWhite,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _ActionCard(
                        icon: LucideIcons.gamepad2,
                        title: 'REMOTE',
                        meta: 'BROADCAST',
                        onTap: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: kWebBlack,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          isScrollControlled: true,
                          builder: (_) => const _UniversalRemoteSheet(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UNIVERSAL REMOTE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _UniversalRemoteSheet extends StatelessWidget {
  const _UniversalRemoteSheet();

  void _cmd(String type, String action, [dynamic value]) {
    sl<HttpServerService>().broadcast(jsonEncode({'type': type, 'action': action, if (value != null) 'value': value}));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: kWebSurface,
        border: Border(top: BorderSide(color: kWebBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('UNIVERSAL REMOTE', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 12, letterSpacing: 4)),
          const SizedBox(height: 32),
          // D-PAD
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_BrutalistRemoteBtn(icon: LucideIcons.chevronUp, onTap: () => _cmd('nav', 'up'))],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BrutalistRemoteBtn(icon: LucideIcons.chevronLeft, onTap: () => _cmd('nav', 'left')),
              const SizedBox(width: 16),
              _BrutalistRemoteBtn(icon: LucideIcons.circle, isPrimary: true, onTap: () => _cmd('nav', 'enter')),
              const SizedBox(width: 16),
              _BrutalistRemoteBtn(icon: LucideIcons.chevronRight, onTap: () => _cmd('nav', 'right')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_BrutalistRemoteBtn(icon: LucideIcons.chevronDown, onTap: () => _cmd('nav', 'down'))],
          ),
          const SizedBox(height: 32),
          Divider(color: kWebBorder),
          const SizedBox(height: 32),

          // MEDIA CONTROLS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BrutalistRemoteBtn(icon: LucideIcons.skipBack, isSmall: true, onTap: () => _cmd('media', 'prev')),
              const SizedBox(width: 16),
              _BrutalistRemoteBtn(icon: LucideIcons.rewind, isSmall: true, onTap: () => _cmd('media', 'seek', -10)),
              const SizedBox(width: 16),
              _BrutalistRemoteBtn(icon: LucideIcons.play, isPrimary: true, onTap: () => _cmd('media', 'toggle_play')),
              const SizedBox(width: 16),
              _BrutalistRemoteBtn(icon: LucideIcons.fastForward, isSmall: true, onTap: () => _cmd('media', 'seek', 10)),
              const SizedBox(width: 16),
              _BrutalistRemoteBtn(icon: LucideIcons.skipForward, isSmall: true, onTap: () => _cmd('media', 'next')),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BrutalistRemoteBtn(icon: LucideIcons.rotateCcw, isSmall: true, onTap: () => _cmd('nav', 'back')),
              const SizedBox(width: 32),
              _BrutalistRemoteBtn(icon: LucideIcons.volume2, isSmall: true, onTap: () => _cmd('media', 'mute')),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _BrutalistRemoteBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isSmall;

  const _BrutalistRemoteBtn({required this.icon, required this.onTap, this.isPrimary = false, this.isSmall = false});

  @override
  State<_BrutalistRemoteBtn> createState() => _BrutalistRemoteBtnState();
}

class _BrutalistRemoteBtnState extends State<_BrutalistRemoteBtn> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final double sz = widget.isSmall ? 48.0 : 64.0;
    final double iconSz = widget.isSmall ? 20.0 : 28.0;

    return Focus(
      onFocusChange: (v) => setState(() => _isFocused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            color: widget.isPrimary ? (_isFocused ? kWebBlack : kWebWhite) : (_isFocused ? kWebWhite : kWebSurface2),
            border: Border.all(color: widget.isPrimary ? (_isFocused ? kWebWhite : kWebBlack) : (_isFocused ? kWebWhite : kWebBorder), width: _isFocused ? 2 : 1),
          ),
          child: Center(
            child: Icon(widget.icon, color: widget.isPrimary ? (_isFocused ? kWebWhite : kWebBlack) : (_isFocused ? kWebBlack : kWebWhite), size: iconSz),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// SHARING TAB
// ─────────────────────────────────────────────────────────────────────────────

class _SharingTab extends StatelessWidget {
  final ServerViewModel state;
  final double pad;
  final bool isMobile;
  const _SharingTab({required this.state, required this.pad, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 24, pad, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Web Interface Theme
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kWebBorder),
                  color: kWebSurface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _TerminalHeader(title: 'WEB UI THEME', icon: LucideIcons.layout),
                    _ToggleRow(label: 'SPATIAL VISIONOS UI', icon: LucideIcons.monitor, value: state.useModernWebUI, isMobile: isMobile, onChanged: state.setUseModernWebUI, isLast: true),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Filters
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kWebBorder),
                  color: kWebSurface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _TerminalHeader(title: 'BROADCAST FILTERS', icon: LucideIcons.slidersHorizontal),
                    _ToggleRow(label: 'VIDEO PAYLOADS', icon: LucideIcons.video, value: state.shareVideos, isMobile: isMobile, onChanged: state.setShareVideos),
                    _ToggleRow(label: 'AUDIO PAYLOADS', icon: LucideIcons.music, value: state.shareMusic, isMobile: isMobile, onChanged: state.setShareMusic),
                    _ToggleRow(label: 'IMAGE PAYLOADS', icon: LucideIcons.image, value: state.shareImages, isMobile: isMobile, onChanged: state.setShareImages, isLast: true),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Shared folders
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kWebBorder),
                  color: kWebSurface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: kWebBorder)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.folderOpen, color: kWebWhite, size: 16),
                              const SizedBox(width: 12),
                              Text('MOUNTED DIRECTORIES', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 11, letterSpacing: 1)),
                            ],
                          ),
                          if (!kIsWeb)
                            Actions(
                              actions: {
                                ActivateIntent: CallbackAction<ActivateIntent>(
                                  onInvoke: (_) async {
                                    final picked = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FolderPickerScreen()));
                                    if (picked is String && context.mounted) context.read<ServerViewModel>().addSharedFolder(picked);
                                    return null;
                                  },
                                ),
                              },
                              child: Focus(
                                onKeyEvent: (_, ev) => handleTVSelectKey(ev, () async {
                                  final picked = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FolderPickerScreen()));
                                  if (picked is String && context.mounted) context.read<ServerViewModel>().addSharedFolder(picked);
                                }),
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FolderPickerScreen()));
                                    if (picked is String && context.mounted) context.read<ServerViewModel>().addSharedFolder(picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(border: Border.all(color: kWebWhite)),
                                    child: Text(
                                      '+ MOUNT',
                                      style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: kWebWhite, letterSpacing: 1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (state.sharedFolders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text('NO DIRECTORIES MOUNTED', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2))),
                      )
                    else
                      ...state.sharedFolders.asMap().entries.map((e) => _DirRow(path: e.value, isLast: e.key == state.sharedFolders.length - 1, onRemove: () => state.removeSharedFolder(e.value))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONNECTION HISTORY
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionHistoryScreen extends StatefulWidget {
  const _ConnectionHistoryScreen();

  @override
  State<_ConnectionHistoryScreen> createState() => _ConnectionHistoryScreenState();
}

class _ConnectionHistoryScreenState extends State<_ConnectionHistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerViewModel>();
    final all = state.connectionHistory.where((c) => c.ip.contains(_query)).toList();
    final now = DateTime.now();
    final recent = all.where((c) => now.difference(c.time).inDays <= 1).toList();
    final older = all.where((c) => now.difference(c.time).inDays > 1).toList();

    return Scaffold(
      backgroundColor: kWebBlack,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(opacity: 0.05, child: const CustomPaint(painter: GridPainter())),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isMobile = constraints.maxWidth <= DS.bpMobile;
                final pad = isMobile ? 16.0 : 48.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
                      child: Row(
                        children: [
                          Actions(
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
                                icon: Icon(LucideIcons.arrowLeft, size: isMobile ? 18 : 20, color: kWebWhite),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('SYSTEM LOGS // HISTORY', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 4)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: Text('ACCESS LOGS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: isMobile ? 40 : 56, fontWeight: FontWeight.w900, height: 1.0)),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kWebSurface,
                          border: Border.all(color: kWebBorder),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '>',
                                style: GoogleFonts.dmMono(color: kWebTextMuted, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'QUERY IP ADDRESS...',
                                  hintStyle: TextStyle(color: kWebTextMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onChanged: (v) => setState(() => _query = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recent.isNotEmpty) ...[
                              Text('RECENT ACTIVITY', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
                              const SizedBox(height: 12),
                              ...recent.map((c) => _HistoryCard(record: c, isMobile: isMobile)),
                              const SizedBox(height: 32),
                            ],
                            if (older.isNotEmpty) ...[
                              Text('ARCHIVED LOGS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
                              const SizedBox(height: 12),
                              ...older.map((c) => _HistoryCard(record: c, isMobile: isMobile)),
                            ],
                            if (all.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 60),
                                  child: Column(
                                    children: [
                                      Icon(LucideIcons.history, size: 48, color: kWebTextMuted),
                                      const SizedBox(height: 16),
                                      Text('NO LOGS FOUND', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 12, letterSpacing: 4)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final ConnectionRecord record;
  final bool isMobile;
  const _HistoryCard({required this.record, required this.isMobile});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _focusConnect = false;
  bool _focusPurge = false;

  @override
  Widget build(BuildContext context) {
    final state = context.read<ServerViewModel>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWebSurface,
        border: Border.all(color: kWebBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
            child: Row(
              children: [
                Icon(LucideIcons.hardDrive, color: kWebWhite, size: widget.isMobile ? 20 : 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.record.ip, style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          if (widget.record.isOnline) const _BlinkingDot(isOnline: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.record.network.toUpperCase()} // '
                            '${widget.record.time.month}/${widget.record.time.day} '
                            '${widget.record.time.hour.toString().padLeft(2, '0')}:'
                            '${widget.record.time.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.dmMono(fontSize: 10, color: kWebTextMuted, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${widget.record.transferGB.toStringAsFixed(1)} GB',
                  style: GoogleFonts.dmMono(color: kWebWhite, fontSize: widget.isMobile ? 18 : 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(height: 1, color: kWebBorder),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Actions(
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        if (widget.record.isOnline) _connect(context);
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    onFocusChange: (v) => setState(() => _focusConnect = v),
                    onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.record.isOnline ? () => _connect(context) : null),
                    child: InkWell(
                      onTap: widget.record.isOnline ? () => _connect(context) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _focusConnect ? kWebWhite : (widget.record.isOnline ? kWebSurface2 : Colors.transparent),
                          border: Border(
                            right: BorderSide(color: kWebBorder),
                            bottom: BorderSide(color: _focusConnect ? kWebWhite : Colors.transparent, width: 2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.record.isOnline ? LucideIcons.cloudLightning : LucideIcons.wifiZero, size: 16, color: _focusConnect ? kWebBlack : (widget.record.isOnline ? kWebWhite : kWebTextMuted)),
                            const SizedBox(width: 12),
                            Text(
                              widget.record.isOnline ? 'CONNECT NODE' : 'NODE OFFLINE',
                              style: GoogleFonts.dmMono(color: _focusConnect ? kWebBlack : (widget.record.isOnline ? kWebWhite : kWebTextMuted), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Actions(
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        state.forgetConnection(widget.record);
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    onFocusChange: (v) => setState(() => _focusPurge = v),
                    onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => state.forgetConnection(widget.record)),
                    child: InkWell(
                      onTap: () => state.forgetConnection(widget.record),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _focusPurge ? kWebWhite : Colors.transparent,
                          border: Border(bottom: BorderSide(color: _focusPurge ? kWebWhite : Colors.transparent, width: 2)),
                        ),
                        child: Center(
                          child: Text(
                            'PURGE',
                            style: GoogleFonts.dmMono(color: _focusPurge ? kWebBlack : kWebTextMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _connect(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: kWebWhite)),
    );
    final vm = ClientViewModel();
    final ok = await vm.connect(widget.record.ip);
    if (context.mounted) Navigator.pop(context);
    if (ok && context.mounted) {
      final isTV = MediaQuery.sizeOf(context).width >= DS.bpTV;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(value: vm, child: isTV ? const TVSelectionScreen() : const MobileSelectionScreen()),
        ),
      );
    }
  }
}

// ── Isolate helper ────────────────────────────────────────────────────────────

List<String> _listSubdirectories(String rootPath) {
  try {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) return [];
    return dir.listSync(followLinks: false).whereType<Directory>().map((d) => d.path).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  } catch (_) {
    return [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLDER PICKER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class FolderPickerScreen extends StatefulWidget {
  const FolderPickerScreen({super.key});

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  String _path = '';
  List<String> _dirs = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        _path = 'C:\\';
      } else if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        _path = '/storage/emulated/0';
      } else {
        _path = '/';
      }
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dirs = await compute(_listSubdirectories, _path);
      if (mounted) {
        setState(() {
          _dirs = dirs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dirs = [];
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _goUp() {
    if (_path.isEmpty) return;
    final parent = Directory(_path).parent;
    if (parent.path != _path) {
      _path = parent.path;
      _load();
    }
  }

  void _navigateInto(String dirPath) {
    _path = dirPath;
    _load();
  }

  String _lastName(String path) {
    final sep = defaultTargetPlatform == TargetPlatform.windows ? '\\' : '/';
    return path.split(sep).where((s) => s.isNotEmpty).lastOrNull ?? path;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= DS.bpMobile;

    return Scaffold(
      backgroundColor: kWebBlack,
      appBar: AppBar(
        backgroundColor: kWebSurface,
        elevation: 0,
        title: Text('MOUNT DIR', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
              icon: Icon(LucideIcons.arrowLeft, size: isMobile ? 18 : 24, color: kWebWhite),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  Navigator.pop(context, _path);
                  return null;
                },
              ),
            },
            child: Focus(
              onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => Navigator.pop(context, _path)),
              child: TextButton(
                onPressed: () => Navigator.pop(context, _path),
                child: Text(
                  'MOUNT',
                  style: GoogleFonts.dmMono(color: kWebWhite, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: isMobile ? 11 : 13),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: kWebBorder, height: 1),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current path breadcrumb
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder)), color: kWebSurface),
            child: Text(
              _path.toUpperCase(),
              style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: isMobile ? 10 : 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Go up button
          Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _goUp();
                  return null;
                },
              ),
            },
            child: Focus(
              onKeyEvent: (_, ev) => handleTVSelectKey(ev, _goUp),
              child: ListTile(
                dense: true,
                focusColor: kWebWhite,
                leading: Icon(LucideIcons.arrowUpLeft, color: kWebWhite, size: isMobile ? 16 : 20),
                title: Text('LEVEL UP', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: isMobile ? 11 : 12, letterSpacing: 1)),
                onTap: _goUp,
              ),
            ),
          ),

          Container(height: 1, color: kWebBorder),

          // Directory listing
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kWebWhite))
                : _error != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'READ ERROR: $_error',
                  style: GoogleFonts.dmMono(color: Colors.redAccent, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            )
                : _dirs.isEmpty
                ? Center(child: Text('NO SUBDIRECTORIES', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)))
                : ListView.builder(
              itemCount: _dirs.length,
              itemBuilder: (_, i) {
                final dirPath = _dirs[i];
                final name = _lastName(dirPath);
                return Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: kWebBorder)),
                  ),
                  child: Actions(
                    actions: {
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (_) {
                          _navigateInto(dirPath);
                          return null;
                        },
                      ),
                    },
                    child: Focus(
                      onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => _navigateInto(dirPath)),
                      child: ListTile(
                        dense: true,
                        focusColor: kWebWhite.withValues(alpha: 0.1),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        leading: Icon(LucideIcons.folder, color: kWebWhite, size: isMobile ? 16 : 20),
                        title: Text(
                          name.toUpperCase(),
                          style: GoogleFonts.dmMono(color: kWebWhite, fontSize: isMobile ? 11 : 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(LucideIcons.chevronRight, size: 14, color: kWebTextMuted),
                        onTap: () => _navigateInto(dirPath),
                      ),
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
// SHARED MICRO-COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _TerminalHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _TerminalHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: kWebBorder)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: kWebTextMuted, size: 16),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
      ],
    ),
  );
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool isMobile;
  const _StatBox({required this.label, required this.value, this.unit, required this.isMobile});

  @override
  Widget build(BuildContext context) => Container(
    height: isMobile ? 100 : 110,
    decoration: BoxDecoration(
      border: Border.all(color: kWebBorder),
      color: kWebSurface,
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.barlowCondensed(fontSize: isMobile ? 32 : 48, color: kWebWhite, fontWeight: FontWeight.bold, height: 1.0),
              ),
              if (unit != null) ...[const SizedBox(width: 8), Text(unit!, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1))],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String meta;
  final bool isRightBorder;
  final bool isBottomBorder;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.title, required this.meta, this.isRightBorder = false, this.isBottomBorder = false, this.isActive = true, required this.onTap});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
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
          handleTVFocusScroll(v, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _isFocused = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 120,
            decoration: BoxDecoration(
              color: _isFocused && widget.isActive ? kWebWhite : Colors.transparent,
              border: Border(
                right: widget.isRightBorder ? BorderSide(color: kWebBorder) : BorderSide.none,
                bottom: widget.isBottomBorder ? BorderSide(color: kWebBorder) : BorderSide.none,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(widget.icon, color: _isFocused && widget.isActive ? kWebBlack : (widget.isActive ? kWebWhite : kWebTextMuted), size: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: _isFocused && widget.isActive ? kWebBlack : (widget.isActive ? kWebWhite : kWebTextMuted)),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.meta, style: GoogleFonts.dmMono(fontSize: 9, letterSpacing: 1, color: widget.isActive ? kWebTextMuted : Colors.redAccent)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrutalistCheckbox extends StatelessWidget {
  final bool value;
  final bool isFocused;
  const _BrutalistCheckbox({required this.value, required this.isFocused});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: value ? (isFocused ? kWebBlack : kWebWhite) : Colors.transparent,
        border: Border.all(color: isFocused ? kWebBlack : kWebWhite, width: 2),
      ),
      child: value ? Center(child: Icon(LucideIcons.check, size: 14, color: isFocused ? kWebWhite : kWebBlack)) : null,
    );
  }
}

class _ToggleRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool value;
  final bool isMobile;
  final bool isLast;
  final Function(bool) onChanged;

  const _ToggleRow({required this.label, required this.icon, required this.value, required this.isMobile, required this.onChanged, this.isLast = false});

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onChanged(!widget.value);
            return null;
          },
        ),
      },
      child: Focus(
        onFocusChange: (v) {
          setState(() => _isFocused = v);
          handleTVFocusScroll(v, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => widget.onChanged(!widget.value)),
        child: InkWell(
          onTap: () => widget.onChanged(!widget.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _isFocused ? kWebWhite : Colors.transparent,
              border: widget.isLast ? null : Border(bottom: BorderSide(color: kWebBorder)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(widget.icon, color: _isFocused ? kWebBlack : (widget.value ? kWebWhite : kWebTextMuted), size: 18),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(widget.label, style: GoogleFonts.dmMono(fontSize: 12, letterSpacing: 1, color: _isFocused ? kWebBlack : (widget.value ? kWebWhite : kWebTextMuted))),
                ),
                _BrutalistCheckbox(value: widget.value, isFocused: _isFocused),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirRow extends StatefulWidget {
  final String path;
  final bool isLast;
  final VoidCallback onRemove;
  const _DirRow({required this.path, required this.isLast, required this.onRemove});

  @override
  State<_DirRow> createState() => _DirRowState();
}

class _DirRowState extends State<_DirRow> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    int count = 0;
    if (!kIsWeb) {
      try {
        count = Directory(widget.path).listSync(followLinks: false).length;
      } catch (_) {}
    }
    return Container(
      decoration: BoxDecoration(
        border: widget.isLast ? null : Border(bottom: BorderSide(color: kWebBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(LucideIcons.folder, color: kWebTextMuted, size: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.path,
                  style: GoogleFonts.dmMono(fontSize: 11, color: kWebWhite, letterSpacing: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('$count ITEMS', style: GoogleFonts.dmMono(fontSize: 9, color: kWebTextMuted, letterSpacing: 1)),
              ],
            ),
          ),
          Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onRemove();
                  return null;
                },
              ),
            },
            child: Focus(
              onFocusChange: (v) => setState(() => _isFocused = v),
              onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onRemove),
              child: InkWell(
                onTap: widget.onRemove,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isFocused ? kWebWhite : Colors.transparent,
                    border: Border.all(color: _isFocused ? kWebWhite : kWebBorder),
                  ),
                  child: Icon(LucideIcons.x, size: 14, color: _isFocused ? kWebBlack : kWebTextMuted),
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
// STATIONS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _StationsTab extends StatelessWidget {
  final ServerViewModel state;
  final double pad;
  final bool isMobile;
  const _StationsTab({required this.state, required this.pad, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 24, pad, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kWebBorder),
                  color: kWebSurface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _TerminalHeader(title: 'BROADCAST STATIONS', icon: LucideIcons.radio),
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CREATE NEW STATION', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text('LINEAR PLAYLIST BROADCAST', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _showCreateStationDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(border: Border.all(color: kWebWhite)),
                              child: Text('+', style: GoogleFonts.dmMono(color: kWebWhite, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (state.stations.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text('NO ACTIVE BROADCASTS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 4)),
                  ),
                )
              else
                ...state.stations.map((s) => _StationCard(station: s, state: state, isMobile: isMobile)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateStationDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final items = state.getLocalMediaItems(shareImages: false);
    final selectedItems = <MediaItem>[];
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < DS.bpMobile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kWebBlack,
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
          shape: Border.all(color: kWebWhite, width: 2),
          title: Text('NEW STATION', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
          content: SizedBox(
            width: width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 13),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'STATION NAME',
                    labelStyle: TextStyle(color: kWebTextMuted, fontSize: 11),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: kWebBorder), borderRadius: BorderRadius.zero),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kWebWhite), borderRadius: BorderRadius.zero),
                  ),
                ),
                const SizedBox(height: 20),
                Text('SELECT MEDIA (${selectedItems.length})', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 10),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: kWebBorder)),
                    child: items.isEmpty
                        ? Center(child: Text('WAITING FOR SCAN...', style: TextStyle(color: kWebTextMuted, fontSize: 10)))
                        : ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        final isSelected = selectedItems.contains(item);
                        return ListTile(
                          dense: true,
                          onTap: () => setDialogState(() => isSelected ? selectedItems.remove(item) : selectedItems.add(item)),
                          leading: Icon(item.isVideo ? LucideIcons.video : LucideIcons.music, color: isSelected ? kWebWhite : kWebTextMuted, size: 18),
                          title: Text(item.title, style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Icon(isSelected ? LucideIcons.checkSquare : LucideIcons.square, color: isSelected ? kWebWhite : kWebTextMuted, size: 18),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL', style: TextStyle(color: kWebTextMuted, fontFamily: 'DM Mono', fontSize: 12))),
            TextButton(
              onPressed: (nameCtrl.text.isEmpty || selectedItems.isEmpty)
                  ? null
                  : () {
                state.createStation(nameCtrl.text, selectedItems);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: kWebWhite,
                    content: Text('BROADCAST "${nameCtrl.text.toUpperCase()}" INITIATED', style: const TextStyle(color: kWebBlack, fontWeight: FontWeight.bold, fontFamily: 'DM Mono', fontSize: 12)),
                  ),
                );
              },
              child: Text('BROADCAST', style: TextStyle(color: (nameCtrl.text.isEmpty || selectedItems.isEmpty) ? kWebTextMuted : kWebWhite, fontFamily: 'DM Mono', fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final BroadcastStation station;
  final ServerViewModel state;
  final bool isMobile;
  const _StationCard({required this.station, required this.state, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: station.isActive ? kWebBorder : kWebBorder.withValues(alpha: 0.05)),
        color: kWebSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  station.isActive ? LucideIcons.radio : LucideIcons.radioTower,
                  color: station.isActive ? kWebWhite : kWebTextMuted,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name.toUpperCase(),
                        style: GoogleFonts.barlowCondensed(
                          color: station.isActive ? kWebWhite : kWebTextMuted,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          decoration: station.isActive ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${station.playlist.length} ITEMS // ${station.totalDuration.inMinutes} MINS',
                        style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                if (station.isActive)
                  IconButton(
                    icon: Icon(station.isPaused ? LucideIcons.play : LucideIcons.pause, color: kWebWhite, size: 20),
                    onPressed: () => state.toggleStationPlayback(station.id),
                  ),
                IconButton(
                  icon: Icon(station.isActive ? LucideIcons.square : LucideIcons.playCircle, color: kWebWhite, size: 20),
                  onPressed: () => state.toggleStationActive(station.id),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                  onPressed: () => state.removeStation(station.id),
                ),
              ],
            ),
          ),
          Container(height: 1, color: kWebBorder),
          _StationLiveStatus(station: station),
        ],
      ),
    );
  }
}

class _StationLiveStatus extends StatefulWidget {
  final BroadcastStation station;
  const _StationLiveStatus({required this.station});

  @override
  State<_StationLiveStatus> createState() => _StationLiveStatusState();
}

class _StationLiveStatusState extends State<_StationLiveStatus> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.station.isActive) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: kWebSurface2,
        child: Center(
          child: Text(
            'STATION OFFLINE',
            style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
        ),
      );
    }

    final playbackState = sl<StationService>().getPlaybackState(widget.station);
    if (playbackState == null) return const SizedBox();

    final item = playbackState.item;
    final totalMs = item.duration * 1000;
    final progress = totalMs > 0 ? playbackState.position.inMilliseconds / totalMs : 0.0;
    final isPaused = widget.station.isPaused;

    return Container(
      padding: const EdgeInsets.all(20),
      color: kWebSurface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPaused ? 'PAUSED' : 'LIVE NOW',
                style: GoogleFonts.dmMono(
                  color: isPaused ? Colors.orangeAccent : kWebWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.title.toUpperCase(),
                  style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(height: 2, color: kWebBlack),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 2,
                  color: isPaused ? Colors.orangeAccent : kWebWhite,
                ),
              ),
            ],
          ),
        ],
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