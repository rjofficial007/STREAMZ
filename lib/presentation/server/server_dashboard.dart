// presentation/server/server_dashboard.dart
// ============================================================================
// STREAMZ — Server NOC Dashboard (Samsung-Style / Brutalist Edition)
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
import '../../domain/models/broadcast_station.dart';
import '../../domain/models/connection_record.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/stream_session.dart';
import '../../domain/services/station_service.dart';
import '../client/client_viewmodel.dart';
import '../mobile/mobile_selection_screen.dart';
import '../shared/theme_settings_screen.dart';
import '../tv/tv_selection_screen.dart';
import 'server_viewmodel.dart';

class ServerDashboard extends StatefulWidget {
  const ServerDashboard({super.key});

  @override
  State<ServerDashboard> createState() => _ServerDashboardState();
}

class _ServerDashboardState extends State<ServerDashboard> {
  final List<String?> _navStack = [null];
  String? get _currentPath => _navStack.last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServerViewModel>().startServer();
    });
  }

  bool _goBack() {
    if (_navStack.length > 1) {
      setState(() {
        _navStack.removeLast();
      });
      return true;
    }
    return false;
  }

  void _navigateTo(String? path) {
    setState(() {
      _navStack.add(path);
    });
  }

  String get _title {
    if (_currentPath == null) return 'SERVER';
    if (_currentPath == 'web_theme') return 'WEB UI THEME';
    if (_currentPath == 'filters') return 'BROADCAST FILTERS';
    if (_currentPath == 'directories') return 'MOUNTED DIRECTORIES';
    return _currentPath!.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerViewModel>();
    final isMobile = DS.isMobile(context);
    final tokens = context.tokens;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (!_goBack()) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: tokens.background,
        body: SafeArea(
          child: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [_buildSliverAppBar(isMobile), ..._buildBodySlivers(isMobile, state)]),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isMobile) {
    final showNav = _currentPath != null;
    final tokens = context.tokens;

    return SliverAppBar(
      backgroundColor: tokens.surface1,
      floating: true,
      elevation: 0,
      pinned: true,
      centerTitle: true,
      titleSpacing: 0,
      leading: showNav
          ? Actions(
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _goBack();
                    return null;
                  },
                ),
              },
              child: Focus(
                onKeyEvent: (_, ev) => handleTVSelectKey(ev, _goBack),
                child: IconButton(
                  icon: Icon(LucideIcons.chevronLeft, size: 20, color: tokens.textPrimary),
                  onPressed: _goBack,
                ),
              ),
            )
          : null,
      automaticallyImplyLeading: false,
      title: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: EdgeInsets.only(left: showNav ? 0 : 16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _title,
                  style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w900, letterSpacing: 4),
                ),
              ),
              if (_currentPath == null)
                IconButton(
                  icon: Icon(LucideIcons.settings, color: tokens.textPrimary, size: 20),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen())),
                ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
      ),
    );
  }

  List<Widget> _buildBodySlivers(bool isMobile, ServerViewModel state) {
    final tokens = context.tokens;
    if (_currentPath == null) {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _EngineAnalysisCard(state: state, isMobile: isMobile),
            ),
          ),
        ),

        // Primary Utility Grid (3 Columns)
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                  color: tokens.border.withValues(alpha: 0.15),
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
                      label: 'LOGS',
                      icon: LucideIcons.history,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ConnectionHistoryScreen())),
                    ),
                    _QuickActionCard(
                      label: 'REMOTE',
                      icon: LucideIcons.gamepad2,
                      onTap: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: tokens.background,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        isScrollControlled: true,
                        builder: (_) => const _UniversalRemoteSheet(),
                      ),
                    ),
                    _QuickActionCard(label: 'QR CODE', icon: LucideIcons.qrCode, onTap: () => _showQRSheet(context, state)),
                    _QuickActionCard(label: 'PREVIEW', icon: LucideIcons.monitor, onTap: () => _showPreviewSheet(context, state)),
                    _QuickActionCard(label: 'WEB UI', icon: LucideIcons.globe, onTap: () => launchUrl(Uri.parse('http://${state.serverIp}:8080'))),
                    _QuickActionCard(label: 'STATIONS', icon: LucideIcons.radio, onTap: () => _navigateTo('stations')),
                    _QuickActionCard(
                      label: 'THEME',
                      icon: LucideIcons.layout,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen())),
                    ),
                    _QuickActionCard(label: 'FILTERS', icon: LucideIcons.slidersHorizontal, onTap: () => _navigateTo('filters')),
                    _QuickActionCard(label: 'DIRECTORIES', icon: LucideIcons.folderOpen, onTap: () => _navigateTo('directories')),
                  ],
                ),
              ),
            ),
          ),
        ),

        _buildTelemetrySlivers(isMobile, state),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ];
    }

    if (_currentPath == 'network') {
      return [
        SliverToBoxAdapter(
          child: _NetworkTab(state: state, pad: 16, isMobile: isMobile),
        ),
      ];
    }

    if (_currentPath == 'web_theme') {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
                    color: tokens.surface1,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _TerminalHeader(title: 'WEB UI THEME', icon: LucideIcons.layout),
                      _ToggleRow(label: 'SPATIAL VISIONOS UI', icon: LucideIcons.monitor, value: state.useModernWebUI, isMobile: isMobile, onChanged: state.setUseModernWebUI, isLast: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (_currentPath == 'filters') {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
                  color: tokens.surface1,
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
            ),
          ),
        ),
      ];
    }

    if (_currentPath == 'directories') {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
                  color: tokens.surface1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.folderOpen, color: tokens.textPrimary, size: 16),
                              const SizedBox(width: 12),
                              Text('MOUNTED DIRECTORIES', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 11, letterSpacing: 1)),
                            ],
                          ),
                          if (!kIsWeb) _MountButton(onMounted: (path) => state.addSharedFolder(path)),
                        ],
                      ),
                    ),
                    if (state.sharedFolders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('NO DIRECTORIES MOUNTED', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 2)),
                        ),
                      )
                    else
                      ...state.sharedFolders.asMap().entries.map((e) => _DirRow(path: e.value, isLast: e.key == state.sharedFolders.length - 1, onRemove: () => state.removeSharedFolder(e.value))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (_currentPath == 'stations') {
      return [
        SliverToBoxAdapter(
          child: _StationsTab(state: state, pad: 16, isMobile: isMobile),
        ),
      ];
    }

    return [const SliverToBoxAdapter(child: Center(child: Text('ERROR')))];
  }

  Widget _buildTelemetrySlivers(bool isMobile, ServerViewModel state) {
    final sessions = state.activeSessions;
    final tokens = context.tokens;
    if (sessions.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(LucideIcons.wifiHigh, size: 40, color: tokens.textMuted),
                    const SizedBox(height: 12),
                    Text('NO SIGNAL DETECTED', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 4)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: DS.isDesktop(context) ? (MediaQuery.sizeOf(context).width - 800) / 2 : 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _TelemetryTile(session: sessions[index], isMobile: isMobile, isFirst: index == 0),
          childCount: sessions.length,
        ),
      ),
    );
  }

  void _showQRSheet(BuildContext context, ServerViewModel state) {
    final tokens = context.tokens;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('QUICK PAIRING', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 12, letterSpacing: 4)),
            const SizedBox(height: 24),
            Container(
              width: 200,
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: tokens.textPrimary, width: 1)),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: state.serverIp, version: QrVersions.auto, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SCAN TO CONNECT NODE',
              style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPreviewSheet(BuildContext context, ServerViewModel state) {
    final tokens = context.tokens;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('UI PREVIEW MODE', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 12, letterSpacing: 4)),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(LucideIcons.smartphone, color: tokens.textPrimary),
              title: Text('MOBILE INTERFACE', style: GoogleFonts.dmMono(color: tokens.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _safePreview(context, false, state);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.tv, color: tokens.textPrimary),
              title: Text('TV INTERFACE', style: GoogleFonts.dmMono(color: tokens.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _safePreview(context, true, state);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _safePreview(BuildContext context, bool isTV, ServerViewModel state) async {
    final tokens = context.tokens;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: tokens.accent)),
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
    }
  }
}

class _MountButton extends StatefulWidget {
  final Function(String) onMounted;
  const _MountButton({required this.onMounted});

  @override
  State<_MountButton> createState() => _MountButtonState();
}

class _MountButtonState extends State<_MountButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) async {
            final picked = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FolderPickerScreen()));
            if (picked is String) widget.onMounted(picked);
            return null;
          },
        ),
      },
      child: Focus(
        onFocusChange: (v) => setState(() => _isFocused = v),
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, () async {
          final picked = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FolderPickerScreen()));
          if (picked is String) widget.onMounted(picked);
        }),
        child: InkWell(
          onTap: () async {
            final picked = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FolderPickerScreen()));
            if (picked is String) widget.onMounted(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: _isFocused ? tokens.background : tokens.textPrimary),
              color: _isFocused ? tokens.textPrimary : Colors.transparent,
            ),
            child: Text(
              '+ MOUNT',
              style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: _isFocused ? tokens.background : tokens.textPrimary, letterSpacing: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _EngineAnalysisCard extends StatefulWidget {
  final ServerViewModel state;
  final bool isMobile;
  const _EngineAnalysisCard({required this.state, required this.isMobile});

  @override
  State<_EngineAnalysisCard> createState() => _EngineAnalysisCardState();
}

class _EngineAnalysisCardState extends State<_EngineAnalysisCard> {
  bool _btnFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
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
              Text(
                'ENGINE ANALYSIS',
                style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              _BlinkingDot(isOnline: widget.state.isRunning),
            ],
          ),
          SizedBox(height: widget.isMobile ? 16 : 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IP ADDRESS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.state.serverIp.toUpperCase(),
                        style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('UPTIME', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      'LIVE',
                      style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: widget.isMobile ? 20 : 24),
          // Progress bar style metric
          Stack(
            children: [
              Container(height: 8, color: tokens.surface2),
              if (widget.state.isRunning)
                FractionallySizedBox(
                  widthFactor: 1.0, // Simulation: fully operational
                  child: Container(height: 8, color: tokens.accent),
                ),
            ],
          ),
          SizedBox(height: widget.isMobile ? 16 : 20),
          Row(
            children: [
              Expanded(child: _legend(context, 'NODES', widget.state.connectedClients.toString(), tokens.accent)),
              const SizedBox(width: 16),
              Expanded(child: _legend(context, 'SPEED', '${widget.state.currentSpeedMb.toStringAsFixed(1)} MB/S', tokens.telemetry)),
            ],
          ),

          SizedBox(height: widget.isMobile ? 16 : 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Actions(
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
                      setState(() => _btnFocused = v);
                      handleTVFocusScroll(v, context);
                    },
                    onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.state.isInitializing ? null : () => widget.state.isRunning ? widget.state.stopServer() : widget.state.startServer()),
                    child: InkWell(
                      onTap: widget.state.isInitializing ? null : () => widget.state.isRunning ? widget.state.stopServer() : widget.state.startServer(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _btnFocused ? tokens.textPrimary : Colors.transparent,
                          border: Border.all(color: tokens.textPrimary),
                        ),
                        child: Center(
                          child: widget.state.isInitializing
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  widget.state.isRunning ? 'STOP ENGINE' : 'START ENGINE',
                                  style: GoogleFonts.dmMono(color: _btnFocused ? tokens.background : tokens.textPrimary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
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

  Widget _legend(BuildContext context, String label, String value, Color color) {
    final tokens = context.tokens;
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10)),
        ),
        Text(
          value,
          style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textPrimary),
        ),
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
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
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
            color: _isFocused ? tokens.textPrimary : tokens.background,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: _isFocused ? tokens.background : tokens.textPrimary, size: 24),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.dmMono(color: _isFocused ? tokens.background : tokens.textSecondary, fontSize: 9, letterSpacing: 1),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryButton({required this.label, required this.icon, required this.onTap});

  @override
  State<_CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<_CategoryButton> {
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
        decoration: BoxDecoration(
          color: _isPressed ? tokens.textPrimary.withValues(alpha: 0.05) : Colors.transparent,
          border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(widget.icon, size: 24, color: tokens.textPrimary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.label,
                style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
            Icon(LucideIcons.chevronRight, color: tokens.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TelemetryTile extends StatefulWidget {
  final StreamSession session;
  final bool isMobile;
  final bool isFirst;

  const _TelemetryTile({required this.session, required this.isMobile, required this.isFirst});

  @override
  State<_TelemetryTile> createState() => _TelemetryTileState();
}

class _TelemetryTileState extends State<_TelemetryTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final safeProgress = widget.session.progress.isFinite ? widget.session.progress.clamp(0.0, 1.0) : 0.0;

    return Focus(
      onFocusChange: (v) {
        setState(() => _isFocused = v);
        handleTVFocusScroll(v, context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isFocused ? tokens.textPrimary.withValues(alpha: 0.1) : tokens.surface1,
          border: Border(
            bottom: BorderSide(color: _isFocused ? tokens.accent : tokens.border.withValues(alpha: 0.15)),
            top: widget.isFirst ? BorderSide(color: _isFocused ? tokens.accent : tokens.border.withValues(alpha: 0.15)) : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.surface2,
                border: Border.all(color: _isFocused ? tokens.accent : tokens.border.withValues(alpha: 0.15)),
              ),
              child: Icon(
                widget.session.mediaType == 'video' ? LucideIcons.film : (widget.session.mediaType == 'audio' ? LucideIcons.activity : LucideIcons.download),
                color: tokens.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.session.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 3),
                  Text('NODE: ${widget.session.clientId.toUpperCase()}', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 1)),
                  if (safeProgress > 0) ...[
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(height: 1, color: tokens.surface2),
                        FractionallySizedBox(
                          widthFactor: safeProgress,
                          child: Container(height: 1, color: tokens.telemetry),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NETWORK TAB (Used as Sub-view)
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkTab extends StatelessWidget {
  final ServerViewModel state;
  final double pad;
  final bool isMobile;
  const _NetworkTab({required this.state, required this.pad, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
            color: tokens.surface1,
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ConnectionHistoryScreen())),
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
                              style: GoogleFonts.dmMono(color: tokens.background, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: tokens.textPrimary,
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
                        backgroundColor: tokens.background,
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
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RemoteAnalysisCard(),

              // Navigation Grid (3 Columns)
              Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                  color: tokens.border.withValues(alpha: 0.15),
                ),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                  children: [
                    const SizedBox(), // Empty spacer
                    _QuickActionCard(label: 'UP', icon: LucideIcons.chevronUp, onTap: () => _cmd('nav', 'up')),
                    const SizedBox(), // Empty spacer

                    _QuickActionCard(label: 'LEFT', icon: LucideIcons.chevronLeft, onTap: () => _cmd('nav', 'left')),
                    _QuickActionCard(label: 'ENTER', icon: LucideIcons.circle, onTap: () => _cmd('nav', 'enter')),
                    _QuickActionCard(label: 'RIGHT', icon: LucideIcons.chevronRight, onTap: () => _cmd('nav', 'right')),

                    const SizedBox(), // Empty spacer
                    _QuickActionCard(label: 'DOWN', icon: LucideIcons.chevronDown, onTap: () => _cmd('nav', 'down')),
                    const SizedBox(), // Empty spacer
                  ],
                ),
              ),

              // Media Grid (3 Columns)
              Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                  color: tokens.border.withValues(alpha: 0.15),
                ),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                  children: [
                    _QuickActionCard(label: 'PREV', icon: LucideIcons.skipBack, onTap: () => _cmd('media', 'prev')),
                    _QuickActionCard(label: 'PLAY/PAUSE', icon: LucideIcons.play, onTap: () => _cmd('media', 'toggle_play')),
                    _QuickActionCard(label: 'NEXT', icon: LucideIcons.skipForward, onTap: () => _cmd('media', 'next')),

                    _QuickActionCard(label: '-10S', icon: LucideIcons.rewind, onTap: () => _cmd('media', 'seek', -10)),
                    _QuickActionCard(label: 'BACK', icon: LucideIcons.rotateCcw, onTap: () => _cmd('nav', 'back')),
                    _QuickActionCard(label: '+10S', icon: LucideIcons.fastForward, onTap: () => _cmd('media', 'seek', 10)),
                  ],
                ),
              ),

              // System & Extra Navigation Grid (3 Columns)
              Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                  color: tokens.border.withValues(alpha: 0.15),
                ),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                  children: [
                    _QuickActionCard(label: 'VOL UP', icon: LucideIcons.volume2, onTap: () => _cmd('system', 'volume_up')),
                    _QuickActionCard(label: 'HOME', icon: LucideIcons.home, onTap: () => _cmd('nav', 'home')),
                    _QuickActionCard(label: 'VOL DOWN', icon: LucideIcons.volume1, onTap: () => _cmd('system', 'volume_down')),

                    _QuickActionCard(label: 'MUTE', icon: LucideIcons.volumeX, onTap: () => _cmd('system', 'mute')),
                    _QuickActionCard(label: 'STOP', icon: LucideIcons.square, onTap: () => _cmd('media', 'stop')),
                    _QuickActionCard(label: 'SHUTDOWN', icon: LucideIcons.power, onTap: () => _cmd('system', 'shutdown')),
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

class _RemoteAnalysisCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COMMAND ANALYSIS',
                style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const _BlinkingDot(isOnline: true),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LINK STATUS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      'ACTIVE',
                      style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('SIGNAL TARGET', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      'BROADCAST',
                      style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(height: 8, color: tokens.surface2),
              FractionallySizedBox(widthFactor: 1.0, child: Container(height: 8, color: tokens.accent)),
            ],
          ),
        ],
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
    final isMobile = DS.isMobile(context);
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isMobile),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchField(),
                      if (recent.isNotEmpty) ...[
                        const _TerminalHeader(title: 'RECENT ACTIVITY', icon: LucideIcons.history),
                        ...recent.map((c) => _HistoryCard(record: c, isMobile: isMobile)),
                        const SizedBox(height: 24),
                      ],
                      if (older.isNotEmpty) ...[const _TerminalHeader(title: 'ARCHIVED LOGS', icon: LucideIcons.archive), ...older.map((c) => _HistoryCard(record: c, isMobile: isMobile))],
                      if (all.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 80),
                            child: Column(
                              children: [
                                Icon(LucideIcons.history, size: 48, color: tokens.textMuted),
                                const SizedBox(height: 16),
                                Text('NO LOGS FOUND', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 12, letterSpacing: 4)),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isMobile) {
    final tokens = context.tokens;
    return SliverAppBar(
      backgroundColor: tokens.surface1,
      floating: true,
      elevation: 0,
      pinned: true,
      centerTitle: true,
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
            icon: Icon(LucideIcons.chevronLeft, size: 20, color: tokens.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      automaticallyImplyLeading: false,
      title: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'SYSTEM LOGS',
                style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w900, letterSpacing: 4),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
      ),
    );
  }

  Widget _buildSearchField() {
    final tokens = context.tokens;
    return Focus(
      onFocusChange: (v) => handleTVFocusScroll(v, context),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface1,
          border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '>',
                style: GoogleFonts.dmMono(color: tokens.textMuted, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: TextField(
                style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'QUERY IP ADDRESS...',
                  hintStyle: TextStyle(color: tokens.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ],
        ),
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
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final state = context.read<ServerViewModel>();
    final tokens = context.tokens;
    return Focus(
      onFocusChange: (v) => setState(() => _isFocused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isFocused ? tokens.textPrimary.withValues(alpha: 0.05) : tokens.surface1,
          border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
                    ),
                    child: Icon(LucideIcons.hardDrive, color: tokens.textSecondary, size: 18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.record.ip,
                              style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(width: 12),
                            if (widget.record.isOnline) const _BlinkingDot(isOnline: true),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.record.network.toUpperCase()} // '
                          '${widget.record.time.month}/${widget.record.time.day} '
                          '${widget.record.time.hour.toString().padLeft(2, '0')}:'
                          '${widget.record.time.minute.toString().padLeft(2, '0')}',
                          style: GoogleFonts.dmMono(fontSize: 9, color: tokens.textMuted, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.record.transferGB.toStringAsFixed(1)} GB',
                    style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: tokens.border.withValues(alpha: 0.05)),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _focusConnect ? tokens.textPrimary : Colors.transparent,
                            border: Border(right: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.record.isOnline ? LucideIcons.cloudLightning : LucideIcons.wifiZero,
                                size: 14,
                                color: _focusConnect ? tokens.background : (widget.record.isOnline ? tokens.textPrimary : tokens.textMuted),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.record.isOnline ? 'CONNECT' : 'OFFLINE',
                                style: GoogleFonts.dmMono(
                                  color: _focusConnect ? tokens.background : (widget.record.isOnline ? tokens.textPrimary : tokens.textMuted),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: _focusPurge ? tokens.textPrimary : Colors.transparent),
                          child: Center(
                            child: Text(
                              'PURGE',
                              style: GoogleFonts.dmMono(color: _focusPurge ? tokens.background : tokens.textMuted, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2),
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
      ),
    );
  }

  Future<void> _connect(BuildContext context) async {
    final tokens = context.tokens;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: tokens.textPrimary)),
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
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.surface1,
        elevation: 0,
        title: Text(
          'MOUNT DIR',
          style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
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
              icon: Icon(LucideIcons.arrowLeft, size: isMobile ? 18 : 24, color: tokens.textPrimary),
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
                  style: GoogleFonts.dmMono(color: tokens.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: isMobile ? 11 : 13),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current path breadcrumb
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
              color: tokens.surface1,
            ),
            child: Text(
              _path.toUpperCase(),
              style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: isMobile ? 10 : 12),
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
                focusColor: tokens.textPrimary.withValues(alpha: 0.1),
                leading: Icon(LucideIcons.arrowUpLeft, color: tokens.textPrimary, size: isMobile ? 16 : 20),
                title: Text(
                  'LEVEL UP',
                  style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: isMobile ? 11 : 12, letterSpacing: 1),
                ),
                onTap: _goUp,
              ),
            ),
          ),

          Container(height: 1, color: tokens.border.withValues(alpha: 0.15)),

          // Directory listing
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: tokens.textPrimary))
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'READ ERROR: $_error',
                        style: GoogleFonts.dmMono(color: tokens.error, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _dirs.isEmpty
                ? Center(
                    child: Text('NO SUBDIRECTORIES', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 2)),
                  )
                : ListView.builder(
                    itemCount: _dirs.length,
                    itemBuilder: (_, i) {
                      final dirPath = _dirs[i];
                      final name = _lastName(dirPath);
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
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
                              focusColor: tokens.textPrimary.withValues(alpha: 0.1),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              leading: Icon(LucideIcons.folder, color: tokens.textPrimary, size: isMobile ? 16 : 20),
                              title: Text(
                                name.toUpperCase(),
                                style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: isMobile ? 11 : 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(LucideIcons.chevronRight, size: 14, color: tokens.textMuted),
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
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface2.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: tokens.textMuted.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: tokens.textMuted, size: 12),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.dmMono(
              color: tokens.textPrimary,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            'LOG_0x${(title.hashCode % 0xFFFF).toRadixString(16).padLeft(4, '0').toUpperCase()}',
            style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 8),
          ),
        ],
      ),
    );
  }
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
    final tokens = context.tokens;
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
              color: _isFocused && widget.isActive ? tokens.textPrimary : Colors.transparent,
              border: Border(
                right: widget.isRightBorder ? BorderSide(color: tokens.border.withValues(alpha: 0.15)) : BorderSide.none,
                bottom: widget.isBottomBorder ? BorderSide(color: tokens.border.withValues(alpha: 0.15)) : BorderSide.none,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(widget.icon, color: _isFocused && widget.isActive ? tokens.background : (widget.isActive ? tokens.textPrimary : tokens.textMuted), size: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.dmMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: _isFocused && widget.isActive ? tokens.background : (widget.isActive ? tokens.textPrimary : tokens.textMuted),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.meta, style: GoogleFonts.dmMono(fontSize: 9, letterSpacing: 1, color: widget.isActive ? tokens.textMuted : tokens.error)),
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
    final tokens = context.tokens;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: value ? (isFocused ? tokens.background : tokens.textPrimary) : Colors.transparent,
        border: Border.all(color: isFocused ? tokens.background : tokens.textPrimary, width: 2),
      ),
      child: value ? Center(child: Icon(LucideIcons.check, size: 14, color: isFocused ? tokens.textPrimary : tokens.background)) : null,
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
    final tokens = context.tokens;
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
              color: _isFocused ? tokens.textPrimary : Colors.transparent,
              border: widget.isLast ? null : Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(widget.icon, color: _isFocused ? tokens.background : (widget.value ? tokens.textPrimary : tokens.textMuted), size: 18),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(widget.label, style: GoogleFonts.dmMono(fontSize: 12, letterSpacing: 1, color: _isFocused ? tokens.background : (widget.value ? tokens.textPrimary : tokens.textMuted))),
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
    final tokens = context.tokens;
    int count = 0;
    if (!kIsWeb) {
      try {
        count = Directory(widget.path).listSync(followLinks: false).length;
      } catch (_) {}
    }
    return Container(
      decoration: BoxDecoration(
        border: widget.isLast ? null : Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(LucideIcons.folder, color: tokens.textMuted, size: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.path,
                  style: GoogleFonts.dmMono(fontSize: 11, color: tokens.textPrimary, letterSpacing: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('$count ITEMS', style: GoogleFonts.dmMono(fontSize: 9, color: tokens.textMuted, letterSpacing: 1)),
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
                    color: _isFocused ? tokens.textPrimary : Colors.transparent,
                    border: Border.all(color: _isFocused ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15)),
                  ),
                  child: Icon(LucideIcons.x, size: 14, color: _isFocused ? tokens.background : tokens.textMuted),
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

class _StationsTab extends StatefulWidget {
  final ServerViewModel state;
  final double pad;
  final bool isMobile;
  const _StationsTab({required this.state, required this.pad, required this.isMobile});

  @override
  State<_StationsTab> createState() => _StationsTabState();
}

class _StationsTabState extends State<_StationsTab> {
  bool _addFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
                color: tokens.surface1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CREATE NEW STATION',
                                style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
                              Text('LINEAR PLAYLIST BROADCAST', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        Actions(
                          actions: {
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) {
                                _showCreateStationDialog(context);
                                return null;
                              },
                            ),
                          },
                          child: Focus(
                            onFocusChange: (v) {
                              setState(() => _addFocused = v);
                              handleTVFocusScroll(v, context);
                            },
                            onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => _showCreateStationDialog(context)),
                            child: InkWell(
                              onTap: () => _showCreateStationDialog(context),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _addFocused ? tokens.textPrimary : Colors.transparent,
                                  border: Border.all(color: tokens.textPrimary),
                                ),
                                child: Text(
                                  '+',
                                  style: GoogleFonts.dmMono(color: _addFocused ? tokens.background : tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // const SizedBox(height: 24),
            if (widget.state.stations.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('NO ACTIVE BROADCASTS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 4)),
                ),
              )
            else
              ...widget.state.stations.map((s) => _StationCard(station: s, state: widget.state, isMobile: widget.isMobile)),
          ],
        ),
      ),
    );
  }

  void _showCreateStationDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final items = widget.state.getLocalMediaItems(shareImages: false);
    final selectedItems = <MediaItem>[];
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < DS.bpMobile;
    final tokens = context.tokens;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.background,
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
          shape: Border.all(color: tokens.textPrimary, width: 2),
          title: Text(
            'NEW STATION',
            style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          content: SizedBox(
            width: width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 13),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'STATION NAME',
                    labelStyle: TextStyle(color: tokens.textMuted, fontSize: 11),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: tokens.border.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.zero,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: tokens.textPrimary),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('SELECT MEDIA (${selectedItems.length})', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 10),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15))),
                    child: items.isEmpty
                        ? Center(
                            child: Text('WAITING FOR SCAN...', style: TextStyle(color: tokens.textMuted, fontSize: 10)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (ctx, i) {
                              final item = items[i];
                              final isSelected = selectedItems.contains(item);
                              return ListTile(
                                dense: true,
                                onTap: () => setDialogState(() => isSelected ? selectedItems.remove(item) : selectedItems.add(item)),
                                leading: Icon(item.isVideo ? LucideIcons.video : LucideIcons.music, color: isSelected ? tokens.textPrimary : tokens.textMuted, size: 18),
                                title: Text(
                                  item.title,
                                  style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Icon(isSelected ? LucideIcons.checkSquare : LucideIcons.square, color: isSelected ? tokens.textPrimary : tokens.textMuted, size: 18),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'CANCEL',
                style: TextStyle(color: tokens.textMuted, fontFamily: 'DM Mono', fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: (nameCtrl.text.isEmpty || selectedItems.isEmpty)
                  ? null
                  : () {
                      widget.state.createStation(nameCtrl.text, selectedItems);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: tokens.textPrimary,
                          content: Text(
                            'BROADCAST "${nameCtrl.text.toUpperCase()}" INITIATED',
                            style: TextStyle(color: tokens.background, fontWeight: FontWeight.bold, fontFamily: 'DM Mono', fontSize: 12),
                          ),
                        ),
                      );
                    },
              child: Text(
                'BROADCAST',
                style: TextStyle(color: (nameCtrl.text.isEmpty || selectedItems.isEmpty) ? tokens.textMuted : tokens.textPrimary, fontFamily: 'DM Mono', fontSize: 12, fontWeight: FontWeight.bold),
              ),
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
    final tokens = context.tokens;
    return Container(
      // margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: station.isActive ? tokens.border.withValues(alpha: 0.3) : tokens.border.withValues(alpha: 0.05)),
        color: tokens.surface1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(station.isActive ? LucideIcons.radio : LucideIcons.radioTower, color: station.isActive ? tokens.textPrimary : tokens.textMuted, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name.toUpperCase(),
                        style: GoogleFonts.barlowCondensed(
                          color: station.isActive ? tokens.textPrimary : tokens.textMuted,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          decoration: station.isActive ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${station.playlist.length} ITEMS // ${station.totalDuration.inMinutes} MINS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)),
                    ],
                  ),
                ),
                if (station.isActive) _BrutalistIconButton(icon: station.isPaused ? LucideIcons.play : LucideIcons.pause, onTap: () => state.toggleStationPlayback(station.id)),
                _BrutalistIconButton(icon: station.isActive ? LucideIcons.square : LucideIcons.playCircle, onTap: () => state.toggleStationActive(station.id)),
                _BrutalistIconButton(icon: LucideIcons.trash2, color: tokens.error, onTap: () => state.removeStation(station.id)),
              ],
            ),
          ),
          Container(height: 1, color: tokens.border.withValues(alpha: 0.15)),
          _StationLiveStatus(station: station),
        ],
      ),
    );
  }
}

class _BrutalistIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _BrutalistIconButton({required this.icon, required this.onTap, this.color});

  @override
  State<_BrutalistIconButton> createState() => _BrutalistIconButtonState();
}

class _BrutalistIconButtonState extends State<_BrutalistIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isFocused ? tokens.textPrimary : Colors.transparent,
              border: Border.all(color: _isFocused ? tokens.textPrimary : Colors.transparent),
            ),
            child: Icon(widget.icon, color: _isFocused ? tokens.background : (widget.color ?? tokens.textPrimary), size: 20),
          ),
        ),
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
    final tokens = context.tokens;
    if (!widget.station.isActive) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: tokens.surface2,
        child: Center(
          child: Text(
            'STATION OFFLINE',
            style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 4),
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
      color: tokens.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPaused ? 'PAUSED' : 'LIVE NOW',
                style: GoogleFonts.dmMono(color: isPaused ? tokens.warning : tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.title.toUpperCase(),
                  style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1),
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
              Container(height: 2, color: tokens.background),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(height: 2, color: isPaused ? tokens.warning : tokens.textPrimary),
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
    final tokens = context.tokens;
    if (!widget.isOnline) return Container(width: 8, height: 8, color: tokens.textMuted.withValues(alpha: 0.3));
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
