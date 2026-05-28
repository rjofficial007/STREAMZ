// presentation/server/server_dashboard.dart
// ============================================================================
// STREAMZ — Server NOC Dashboard
// ============================================================================

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
import '../client/client_viewmodel.dart';
import '../mobile/mobile_selection_screen.dart';
import '../tv/tv_selection_screen.dart';
import 'server_viewmodel.dart';

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
      length: 3,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: Opacity(opacity: 0.12, child: const CustomPaint(painter: GridPainter())),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isDesktop = width > DS.bpTablet;
                  final isMobile = width <= DS.bpMobile;
                  final pad = isDesktop ? DS.s48 : (isMobile ? DS.s16 : DS.s32);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.fromLTRB(pad, isMobile ? DS.s16 : DS.s24, pad, 0),
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
                                      icon: Icon(LucideIcons.arrowLeft, size: isMobile ? 18 : 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: DS.s12),
                                Text('NODE // BROADCAST', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: isMobile ? 10 : 12, letterSpacing: 4)),
                              ],
                            ),
                            SizedBox(height: isMobile ? DS.s8 : DS.s12),
                            Text('SERVER', style: AppTheme.theme.textTheme.displayLarge?.copyWith(fontSize: isMobile ? 48 : 72, height: 1.0)),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? DS.s16 : DS.s24),

                      // Tab bar
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: DS.borderDefault)),
                          child: TabBar(
                            isScrollable: false,
                            indicator: const BoxDecoration(color: DS.accent),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: DS.bg,
                            unselectedLabelColor: DS.textMuted,
                            labelStyle: GoogleFonts.dmMono(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: isMobile ? 10 : 13),
                            tabs: const [
                              Tab(text: 'ACTIVITY'),
                              Tab(text: 'NETWORK'),
                              Tab(text: 'SHARING'),
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
      padding: EdgeInsets.fromLTRB(pad, DS.s24, pad, 40),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _CoreCard(state: state, isMobile: isMobile),
                      const SizedBox(height: DS.s24),
                      _MetricsRow(state: state, isMobile: isMobile),
                      const SizedBox(height: DS.s24),
                      _QRCard(state: state, isMobile: isMobile),
                    ],
                  ),
                ),
                const SizedBox(width: DS.s24),
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
                const SizedBox(height: DS.s16),
                _MetricsRow(state: state, isMobile: isMobile),
                const SizedBox(height: DS.s16),
                _QRCard(state: state, isMobile: isMobile),
                const SizedBox(height: DS.s24),
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
        border: Border.all(color: DS.borderDefault),
        color: DS.surface1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TerminalHeader(title: 'CORE ENGINE', icon: LucideIcons.cpu),
          Padding(
            padding: EdgeInsets.all(widget.isMobile ? DS.s16 : DS.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('IPv4 BROADCAST', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
                    Row(
                      children: [
                        _BlinkingDot(isOnline: widget.state.isRunning),
                        const SizedBox(width: DS.s8),
                        Text(
                          widget.state.isRunning ? 'ONLINE' : 'OFFLINE',
                          style: GoogleFonts.dmMono(color: widget.state.isRunning ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: DS.s12),
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
                      style: AppTheme.theme.textTheme.headlineSmall?.copyWith(color: DS.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: DS.borderDefault),
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
                  padding: EdgeInsets.symmetric(vertical: widget.isMobile ? DS.s16 : DS.s20),
                  color: widget.state.isInitializing ? DS.surface3 : (_isFocused ? Colors.white : DS.accent),
                  child: Center(
                    child: Text(
                      widget.state.isInitializing ? 'BOOTING...' : (widget.state.isRunning ? 'STOP ENGINE' : 'START ENGINE'),
                      style: AppTheme.theme.textTheme.displayLarge?.copyWith(
                        color: widget.state.isInitializing ? DS.textMuted : Colors.black,
                        letterSpacing: 0.8,
                        fontSize: widget.isMobile ? 20 : 72,
                        height: 1.0,
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
        const SizedBox(width: DS.s16),
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
        border: Border.all(color: DS.borderDefault),
        color: DS.surface1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TerminalHeader(title: 'QUICK PAIRING', icon: LucideIcons.qrCode),
          Padding(
            padding: EdgeInsets.all(isMobile ? DS.s24 : DS.s32),
            child: Column(
              children: [
                Container(
                  width: isMobile ? 160 : 200,
                  height: isMobile ? 160 : 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: DS.accent, width: 2)),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(data: state.serverIp, version: QrVersions.auto, backgroundColor: Colors.white),
                  ),
                ),
                SizedBox(height: isMobile ? DS.s24 : DS.s32),
                Text('SCAN TO INITIATE HANDSHAKE', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 2), textAlign: TextAlign.center),
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
        border: Border.all(color: DS.borderDefault),
        color: DS.surface1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TerminalHeader(title: 'LIVE TELEMETRY FEED', icon: LucideIcons.activity),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(LucideIcons.wifiHigh, size: 48, color: DS.textMuted),
                    const SizedBox(height: DS.s16),
                    Text('NO SIGNAL DETECTED', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 4)),
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
    Color badgeBg = DS.surface3;
    Color badgeFg = DS.textSecondary;
    String badge = 'STR';

    if (session.mediaType == 'video') {
      badge = 'VID';
      badgeBg = DS.accent;
      badgeFg = DS.bg;
    } else if (session.mediaType == 'audio') {
      badge = 'AUD';
      badgeBg = DS.textPrimary;
      badgeFg = DS.bg;
    } else if (session.mediaType == 'download') {
      badge = 'DWN';
      badgeBg = DS.surface2;
      badgeFg = DS.accent;
    }

    final safeProgress = session.progress.isFinite ? session.progress.clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DS.borderDefault)),
      ),
      padding: EdgeInsets.all(isMobile ? DS.s16 : DS.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: 4),
                color: badgeBg,
                child: Text(
                  badge,
                  style: GoogleFonts.dmMono(color: badgeFg, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
              const SizedBox(width: DS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title.toUpperCase(),
                      style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 12 : 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('NODE_ID : ${session.clientId.toUpperCase()}', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: DS.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (safeProgress > 0) ...[
            const SizedBox(height: DS.s16),
            Stack(
              children: [
                Container(height: 4, color: DS.bg),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: safeProgress,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: DS.accent,
                      boxShadow: [BoxShadow(color: DS.accent.withValues(alpha: 0.5), blurRadius: 6)],
                    ),
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
      builder: (_) => const Center(child: CircularProgressIndicator(color: DS.accent)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preview Connection Failed'), backgroundColor: Colors.redAccent));
    }
  }

  void _showStartEngineWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'START ENGINE FIRST',
          style: TextStyle(fontFamily: 'DM Mono', color: Colors.black),
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, DS.s24, pad, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: DS.borderDefault),
              color: DS.surface1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TerminalHeader(title: 'SYSTEM UTILITIES', icon: LucideIcons.terminal),
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
                            builder: (_) => ChangeNotifierProvider.value(value: context.read<ServerViewModel>(), child: const _ConnectionHistoryScreen()),
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
                            const SnackBar(
                              content: Text(
                                'LINK COPIED',
                                style: TextStyle(fontFamily: 'DM Mono', color: Colors.black),
                              ),
                              backgroundColor: DS.accent,
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
                          backgroundColor: DS.bg,
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
      padding: const EdgeInsets.all(DS.s32),
      decoration: const BoxDecoration(
        color: DS.bg,
        border: Border(top: BorderSide(color: DS.borderDefault)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('UNIVERSAL REMOTE', style: AppTheme.theme.textTheme.labelMedium?.copyWith(letterSpacing: 4)),
          const SizedBox(height: DS.s32),
          // D-PAD
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [BrutalistPlayerBtn(icon: LucideIcons.chevronUp, size: 24, onTap: () => _cmd('nav', 'up'))],
          ),
          const SizedBox(height: DS.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrutalistPlayerBtn(icon: LucideIcons.chevronLeft, size: 24, onTap: () => _cmd('nav', 'left')),
              const SizedBox(width: DS.s16),
              BrutalistPlayerBtn(icon: LucideIcons.circle, isPrimary: true, size: 24, onTap: () => _cmd('nav', 'enter')),
              const SizedBox(width: DS.s16),
              BrutalistPlayerBtn(icon: LucideIcons.chevronRight, size: 24, onTap: () => _cmd('nav', 'right')),
            ],
          ),
          const SizedBox(height: DS.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [BrutalistPlayerBtn(icon: LucideIcons.chevronDown, size: 24, onTap: () => _cmd('nav', 'down'))],
          ),
          const SizedBox(height: DS.s32),
          const Divider(color: DS.borderDefault),
          const SizedBox(height: DS.s32),

          // MEDIA CONTROLS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrutalistPlayerBtn(icon: LucideIcons.skipBack, size: 20, onTap: () => _cmd('media', 'prev')),
              const SizedBox(width: DS.s16),
              BrutalistPlayerBtn(icon: LucideIcons.rewind, size: 20, onTap: () => _cmd('media', 'seek', -10)),
              const SizedBox(width: DS.s16),
              BrutalistPlayerBtn(icon: LucideIcons.play, isPrimary: true, size: 24, onTap: () => _cmd('media', 'toggle_play')),
              const SizedBox(width: DS.s16),
              BrutalistPlayerBtn(icon: LucideIcons.fastForward, size: 20, onTap: () => _cmd('media', 'seek', 10)),
              const SizedBox(width: DS.s16),
              BrutalistPlayerBtn(icon: LucideIcons.skipForward, size: 20, onTap: () => _cmd('media', 'next')),
            ],
          ),
          const SizedBox(height: DS.s24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrutalistPlayerBtn(icon: LucideIcons.rotateCcw, size: 20, onTap: () => _cmd('nav', 'back')),
              const SizedBox(width: DS.s32),
              BrutalistPlayerBtn(icon: LucideIcons.volume2, size: 20, onTap: () => _cmd('media', 'mute')),
            ],
          ),
          const SizedBox(height: DS.s32),
        ],
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
      padding: EdgeInsets.fromLTRB(pad, DS.s24, pad, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Web Interface Theme
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: DS.borderDefault),
                  color: DS.surface1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TerminalHeader(title: 'WEB UI THEME', icon: LucideIcons.layout),
                    _ToggleRow(label: 'SPATIAL VISIONOS UI', icon: LucideIcons.monitor, value: state.useModernWebUI, isMobile: isMobile, onChanged: state.setUseModernWebUI, isLast: true),
                  ],
                ),
              ),

              const SizedBox(height: DS.s24),

              // Filters
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: DS.borderDefault),
                  color: DS.surface1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TerminalHeader(title: 'BROADCAST FILTERS', icon: LucideIcons.slidersHorizontal),
                    _ToggleRow(label: 'VIDEO PAYLOADS', icon: LucideIcons.video, value: state.shareVideos, isMobile: isMobile, onChanged: state.setShareVideos),
                    _ToggleRow(label: 'AUDIO PAYLOADS', icon: LucideIcons.music, value: state.shareMusic, isMobile: isMobile, onChanged: state.setShareMusic),
                    _ToggleRow(label: 'IMAGE PAYLOADS', icon: LucideIcons.image, value: state.shareImages, isMobile: isMobile, onChanged: state.setShareImages, isLast: true),
                  ],
                ),
              ),

              const SizedBox(height: DS.s24),

              // Shared folders
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: DS.borderDefault),
                  color: DS.surface1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: DS.borderDefault)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.folderOpen, color: DS.textPrimary, size: 16),
                              const SizedBox(width: DS.s12),
                              Text('MOUNTED DIRECTORIES', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 11)),
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
                                    padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: 6),
                                    color: DS.accent,
                                    child: Text(
                                      '+ MOUNT',
                                      style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: DS.bg, letterSpacing: 1),
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
                        padding: const EdgeInsets.all(DS.s32),
                        child: Center(child: Text('NO DIRECTORIES MOUNTED', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 2))),
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
      backgroundColor: DS.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(opacity: 0.12, child: const CustomPaint(painter: GridPainter())),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isMobile = constraints.maxWidth <= DS.bpMobile;
                final pad = isMobile ? DS.s16 : DS.s48;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, DS.s16, pad, DS.s16),
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
                                icon: Icon(LucideIcons.arrowLeft, size: isMobile ? 18 : 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: DS.s12),
                          Text('SYSTEM LOGS // HISTORY', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 4)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: Text('ACCESS LOGS', style: AppTheme.theme.textTheme.displayLarge?.copyWith(fontSize: isMobile ? 40 : 56, height: 1.0)),
                    ),
                    const SizedBox(height: DS.s24),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: Container(
                        decoration: BoxDecoration(
                          color: DS.surface1,
                          border: Border.all(color: DS.borderDefault),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(DS.s16),
                              child: Text(
                                '>',
                                style: GoogleFonts.dmMono(color: DS.accent, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                style: GoogleFonts.dmMono(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'QUERY IP ADDRESS...',
                                  hintStyle: TextStyle(color: DS.textMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: DS.s16),
                                ),
                                onChanged: (v) => setState(() => _query = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: DS.s24),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recent.isNotEmpty) ...[
                              Text('RECENT ACTIVITY', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 2)),
                              const SizedBox(height: DS.s12),
                              ...recent.map((c) => _HistoryCard(record: c, isMobile: isMobile)),
                              const SizedBox(height: DS.s32),
                            ],
                            if (older.isNotEmpty) ...[
                              Text('ARCHIVED LOGS', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 2)),
                              const SizedBox(height: DS.s12),
                              ...older.map((c) => _HistoryCard(record: c, isMobile: isMobile)),
                            ],
                            if (all.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 60),
                                  child: Column(
                                    children: [
                                      const Icon(LucideIcons.history, size: 48, color: DS.textMuted),
                                      const SizedBox(height: DS.s16),
                                      Text('NO LOGS FOUND', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 4)),
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
      margin: const EdgeInsets.only(bottom: DS.s12),
      decoration: BoxDecoration(
        color: DS.surface1,
        border: Border.all(color: DS.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(widget.isMobile ? DS.s16 : DS.s24),
            child: Row(
              children: [
                Icon(LucideIcons.hardDrive, color: DS.textPrimary, size: widget.isMobile ? 20 : 24),
                const SizedBox(width: DS.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.record.ip, style: AppTheme.theme.textTheme.titleMedium?.copyWith(fontSize: 16)),
                          const SizedBox(width: DS.s12),
                          if (widget.record.isOnline) const _BlinkingDot(isOnline: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.record.network.toUpperCase()} // '
                        '${widget.record.time.month}/${widget.record.time.day} '
                        '${widget.record.time.hour.toString().padLeft(2, '0')}:'
                        '${widget.record.time.minute.toString().padLeft(2, '0')}',
                        style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: DS.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${widget.record.transferGB.toStringAsFixed(1)} GB',
                  style: AppTheme.theme.textTheme.headlineSmall?.copyWith(color: DS.accent, fontSize: widget.isMobile ? 18 : 24),
                ),
              ],
            ),
          ),
          Container(height: 1, color: DS.borderDefault),
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
                        padding: const EdgeInsets.symmetric(vertical: DS.s16),
                        decoration: BoxDecoration(
                          color: _focusConnect ? DS.surface3 : (widget.record.isOnline ? DS.accent.withValues(alpha: 0.1) : Colors.transparent),
                          border: Border(
                            right: const BorderSide(color: DS.borderDefault),
                            bottom: BorderSide(color: _focusConnect ? DS.accent : Colors.transparent, width: 2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.record.isOnline ? LucideIcons.cloudLightning : LucideIcons.wifiZero, size: 16, color: widget.record.isOnline ? DS.accent : DS.textMuted),
                            const SizedBox(width: DS.s12),
                            Text(
                              widget.record.isOnline ? 'CONNECT NODE' : 'NODE OFFLINE',
                              style: GoogleFonts.dmMono(color: widget.record.isOnline ? DS.accent : DS.textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2),
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
                        padding: const EdgeInsets.symmetric(vertical: DS.s16),
                        decoration: BoxDecoration(
                          color: _focusPurge ? Colors.redAccent.withValues(alpha: 0.1) : Colors.transparent,
                          border: Border(bottom: BorderSide(color: _focusPurge ? Colors.redAccent : Colors.transparent, width: 2)),
                        ),
                        child: Center(
                          child: Text(
                            'PURGE',
                            style: GoogleFonts.dmMono(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2),
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
      builder: (_) => const Center(child: CircularProgressIndicator(color: DS.accent)),
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

/// Runs in a background isolate via compute().
/// Returns a sorted list of subdirectory paths under [rootPath].
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

  // FIX: Use compute() to move directory listing off the main isolate.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // compute() spawns an isolate, runs _listSubdirectories, returns result.
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

    return AppScaffold(
      appBar: AppBar(
        title: Text('MOUNT DIR', style: TextStyle(fontSize: isMobile ? 16 : 20)),
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
              icon: Icon(LucideIcons.arrowLeft, size: isMobile ? 18 : 24),
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
                  style: AppTheme.theme.textTheme.labelMedium?.copyWith(color: DS.accent, fontSize: isMobile ? 11 : 13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current path breadcrumb
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: DS.s16, vertical: isMobile ? DS.s8 : DS.s12),
            decoration: BoxDecoration(border: Border.all(color: DS.borderDefault)),
            child: Text(
              _path.toUpperCase(),
              style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: isMobile ? 10 : 12),
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
                focusColor: DS.surface3,
                leading: Icon(LucideIcons.arrowUpLeft, color: Colors.white, size: isMobile ? 16 : 20),
                title: Text('LEVEL UP', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 11 : 12)),
                onTap: _goUp,
              ),
            ),
          ),

          const Divider(height: 1, color: DS.borderDefault),

          // Directory listing
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: DS.accent, strokeWidth: 2))
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DS.s24),
                      child: Text(
                        'READ ERROR: $_error',
                        style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _dirs.isEmpty
                ? Center(child: Text('NO SUBDIRECTORIES', style: AppTheme.theme.textTheme.labelSmall))
                : ListView.builder(
                    itemCount: _dirs.length,
                    itemBuilder: (_, i) {
                      final dirPath = _dirs[i];
                      final name = _lastName(dirPath);
                      return Container(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: DS.borderDefault)),
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
                              focusColor: DS.surface3,
                              contentPadding: const EdgeInsets.symmetric(horizontal: DS.s16),
                              leading: Icon(LucideIcons.folder, color: DS.accent, size: isMobile ? 16 : 20),
                              title: Text(
                                name.toUpperCase(),
                                style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 11 : 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(LucideIcons.chevronRight, size: 14, color: DS.textMuted),
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
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: DS.borderDefault)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
    child: Row(
      children: [
        Icon(icon, color: DS.textPrimary, size: 16),
        const SizedBox(width: DS.s12),
        Text(title, style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 11)),
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
    height: isMobile ? 90 : 110,
    decoration: BoxDecoration(
      border: Border.all(color: DS.borderDefault),
      color: DS.surface1,
    ),
    padding: const EdgeInsets.all(DS.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTheme.theme.textTheme.headlineSmall?.copyWith(fontSize: isMobile ? 28 : 36, color: DS.accent, height: 1.0),
            ),
            if (unit != null) ...[const SizedBox(width: 4), Text(unit!, style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 10))],
          ],
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
              color: _isFocused && widget.isActive ? DS.surface3 : Colors.transparent,
              border: Border(
                right: widget.isRightBorder ? const BorderSide(color: DS.borderDefault) : BorderSide.none,
                bottom: widget.isBottomBorder ? const BorderSide(color: DS.borderDefault) : BorderSide.none,
              ),
            ),
            padding: const EdgeInsets.all(DS.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(widget.icon, color: _isFocused && widget.isActive ? DS.accent : DS.textMuted, size: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 13, color: _isFocused && widget.isActive ? Colors.white : (widget.isActive ? DS.textPrimary : DS.textMuted)),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.meta, style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: widget.isActive ? DS.textMuted : Colors.redAccent)),
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
              color: _isFocused ? DS.surface3 : Colors.transparent,
              border: widget.isLast ? null : const Border(bottom: BorderSide(color: DS.borderDefault)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s16),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.value ? DS.accent : DS.textMuted, size: 18),
                const SizedBox(width: DS.s16),
                Expanded(
                  child: Text(widget.label, style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 12, color: widget.value ? Colors.white : DS.textMuted)),
                ),
                BrutalistToggle(value: widget.value, isMobile: widget.isMobile),
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
        border: widget.isLast ? null : const Border(bottom: BorderSide(color: DS.borderDefault)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
      child: Row(
        children: [
          const Icon(LucideIcons.folder, color: DS.textMuted, size: 18),
          const SizedBox(width: DS.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.path,
                  style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 11, color: DS.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('$count ITEMS', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: DS.textMuted)),
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
                    color: _isFocused ? Colors.redAccent.withValues(alpha: 0.1) : Colors.transparent,
                    border: Border.all(color: _isFocused ? Colors.redAccent : DS.borderDefault),
                  ),
                  child: Icon(LucideIcons.x, size: 14, color: _isFocused ? Colors.redAccent : DS.textMuted),
                ),
              ),
            ),
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
    if (!widget.isOnline) return Container(width: 8, height: 8, color: Colors.redAccent);
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 4)],
        ),
      ),
    );
  }
}
