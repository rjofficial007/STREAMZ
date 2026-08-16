// presentation/server/server_dashboard.dart
// ============================================================================
// STREAMZ — Server NOC Dashboard (Brutalist Pro Suite)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/data/network/http_server.dart';
import 'package:streamz/data/repositories/server_repository.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/connection_record.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/services/station_service.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/server/server_viewmodel.dart';
import 'package:streamz/presentation/server/widgets/server_engine_card.dart';
import 'package:streamz/presentation/server/widgets/server_quick_action_grid.dart';
import 'package:streamz/presentation/server/widgets/server_telemetry_tile.dart';
import 'package:streamz/presentation/shared/atmospheric_background.dart';
import 'package:streamz/presentation/shared/remote_input_relay_screen.dart';
import 'package:streamz/presentation/shared/theme_settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
    // Autostart server on dashboard entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServerViewModel>().startServer();
    });
  }

  bool _goBack() {
    if (_navStack.length > 1) {
      setState(_navStack.removeLast);
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
    if (_currentPath == 'stations') return 'BROADCAST STATIONS';
    if (_currentPath == 'history') return 'VIEW LOGS';
    return _currentPath!.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerViewModel>();
    final isMobile = DS.isMobile(context);
    final tokens = context.tokens;

    List<Color>? vibeColors;
    if (state.activeSessions.isNotEmpty) {
      final vibeHex = state.activeSessions.first.vibeColors;
      if (vibeHex != null) {
        vibeColors = vibeHex.map((h) => Color(int.parse(h.replaceFirst('#', 'FF'), radix: 16))).toList();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (!_goBack()) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: tokens.background,
        body: AtmosphericBackground(
          colors: vibeColors,
          child: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(isMobile),
                ..._buildBodySlivers(isMobile, state),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _currentPath == null ? const _DashboardCLI() : null,
      ),
    );
  }

  Widget _buildSliverAppBar(bool isMobile) {
    final showNav = _currentPath != null;
    final tokens = context.tokens;

    return SliverAppBar(
      backgroundColor: tokens.surface1.withValues(alpha: 0.8),
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
                  tooltip: 'BACK',
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
                  tooltip: 'SETTINGS',
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
              child: ServerEngineCard(state: state, isMobile: isMobile),
            ),
          ),
        ),

        // Primary Utility Grid (3 Columns)
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: DecoratedBox(
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
                    ServerQuickActionCard(
                      label: 'TRAFFIC',
                      icon: LucideIcons.barChart,
                      onTap: () => _navigateTo('traffic'),
                    ),
                    ServerQuickActionCard(
                      label: 'LIVE LOGS',
                      icon: LucideIcons.terminal,
                      onTap: () => _navigateTo('live_logs'),
                    ),
                    ServerQuickActionCard(
                      label: 'HISTORY',
                      icon: LucideIcons.history,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ConnectionHistoryScreen())),
                    ),
                    ServerQuickActionCard(
                      label: 'RELAY',
                      icon: LucideIcons.smartphoneNfc,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteInputRelayScreen(isServerMode: true))),
                    ),
                    ServerQuickActionCard(
                      label: 'REMOTE',
                      icon: LucideIcons.gamepad2,
                      onTap: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: tokens.background,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        isScrollControlled: true,
                        builder: (_) => const UniversalRemoteSheet(),
                      ),
                    ),
                    ServerQuickActionCard(label: 'QR CODE', icon: LucideIcons.qrCode, onTap: () => _showQRSheet(context, state)),
                    ServerQuickActionCard(label: 'PREVIEW', icon: LucideIcons.monitor, onTap: () => _showPreviewSheet(context, state)),
                    ServerQuickActionCard(label: 'WEB UI', icon: LucideIcons.globe, onTap: () => launchUrl(Uri.parse('http://${state.serverIp}:8080'))),
                    ServerQuickActionCard(label: 'STATIONS', icon: LucideIcons.radio, onTap: () => _navigateTo('stations')),
                    ServerQuickActionCard(
                      label: 'THEME',
                      icon: LucideIcons.layout,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen())),
                    ),
                    ServerQuickActionCard(label: 'FILTERS', icon: LucideIcons.slidersHorizontal, onTap: () => _navigateTo('filters')),
                    ServerQuickActionCard(label: 'DIRECTORIES', icon: LucideIcons.folderOpen, onTap: () => _navigateTo('directories')),
                    ServerQuickActionCard(
                      label: 'REMOTE MEDIA',
                      icon: LucideIcons.playCircle,
                      onTap: () => _showRemoteMediaSheet(context, state),
                    ),
                    ServerQuickActionCard(label: 'CURATE', icon: LucideIcons.wand2, onTap: () => state.curateStation('all')),
                    ServerQuickActionCard(label: 'SYNC ALL', icon: LucideIcons.refreshCw, onTap: () {
                      if (state.activeSessions.isNotEmpty) {
                        final masterId = state.activeSessions.first.clientId;
                        sl<HttpServerService>().broadcast(jsonEncode({'type': 'media', 'action': 'set_sync_mode', 'value': 'master', 'targetId': masterId}));
                        sl<HttpServerService>().broadcast(jsonEncode({'type': 'media', 'action': 'set_sync_mode', 'value': 'slave'}));
                      }
                    }),
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

    if (_currentPath == 'directories') {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
                  color: tokens.surface1.withValues(alpha: 0.4),
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

    if (_currentPath == 'traffic') {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _TrafficMonitor(state: state),
            ),
          ),
        ),
      ];
    }

    if (_currentPath == 'live_logs') {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _LiveLogViewer(state: state),
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
                  color: tokens.surface1.withValues(alpha: 0.4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _TerminalHeader(title: 'BROADCAST FILTERS', icon: LucideIcons.slidersHorizontal),
                    _ToggleRow(label: 'VIDEO PAYLOADS', icon: LucideIcons.video, value: state.shareVideos, isMobile: isMobile, onChanged: state.setShareVideos),
                    _ToggleRow(label: 'AUDIO PAYLOADS', icon: LucideIcons.music, value: state.shareMusic, isMobile: isMobile, onChanged: state.setShareMusic),
                    _ToggleRow(label: 'IMAGE PAYLOADS', icon: LucideIcons.image, value: state.shareImages, isMobile: isMobile, onChanged: state.setShareImages),
                    _ToggleRow(label: 'ZERO-TRACE MODE', icon: LucideIcons.ghost, value: state.zeroTrace, isMobile: isMobile, onChanged: state.setZeroTrace, isLast: true),
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

    if (_currentPath == 'history') {
      return [
        _buildHistorySliver(state),
      ];
    }

    return [const SliverToBoxAdapter(child: Center(child: Text('ERROR')))];
  }

  Widget _buildHistorySliver(ServerViewModel state) {
    final history = sl<ServerRepository>().viewHistory;
    final tokens = context.tokens;

    if (history.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.history, size: 64, color: tokens.textMuted),
              const SizedBox(height: 24),
              Text('NO VIEW HISTORY RECORDED', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 14, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final item = history[i];
            final time = '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}';
            return Container(
              margin: const EdgeInsets.only(bottom: 1),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surface1,
                border: Border.all(color: tokens.border.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    color: tokens.surface2,
                    child: Icon(item.media.isVideo ? LucideIcons.video : LucideIcons.music, size: 20, color: tokens.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.media.title.toUpperCase(), style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('CLIENT: ${item.clientIp} // $time', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: history.length,
        ),
      ),
    );
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
          (context, index) {
            final session = sessions[index];
            return DragTarget<String>(
              onAcceptWithDetails: (details) {
                final fromId = details.data;
                final targetId = session.clientId;
                if (fromId == targetId) return;
                
                state.teleport(fromId, targetId);
              },
              builder: (context, candidateData, rejectedData) => ServerTelemetryTile(
                  session: session, 
                  isMobile: isMobile, 
                  isFirst: index == 0, 
                  isTarget: candidateData.isNotEmpty
                ),
            );
          },
          childCount: sessions.length,
        ),
      ),
    );
  }

  void _showRemoteMediaSheet(BuildContext context, ServerViewModel state) {
    final tokens = context.tokens;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      isScrollControlled: true,
      builder: (_) => _RemoteMediaView(state: state),
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
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: tokens.accent)),
    ));
    final vm = ClientViewModel();
    try {
      final ok = await vm.connect(state.serverIp);
      if (context.mounted) Navigator.pop(context);
      if (ok && context.mounted) {
        unawaited(context.push('/client/interface'));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: tokens.error,
            content: Text('PREVIEW CONNECTION FAILED: ${vm.connectionError ?? "UNKNOWN"}', style: GoogleFonts.dmMono(color: tokens.background)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: tokens.error,
            content: Text('PREVIEW ERROR: $e', style: GoogleFonts.dmMono(color: tokens.background)),
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _RemoteMediaView extends StatefulWidget {
  const _RemoteMediaView({required this.state});
  final ServerViewModel state;

  @override
  State<_RemoteMediaView> createState() => _RemoteMediaViewState();
}

class _RemoteMediaViewState extends State<_RemoteMediaView> {
  String _query = '';
  String? _targetId;

  void _play(MediaItem item) {
    sl<HttpServerService>().broadcast(jsonEncode({
      'type': 'media',
      'action': 'play',
      'value': item.toJson(),
      if (_targetId != null) 'targetId': _targetId,
    }));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'BROADCASTING: ${item.title.toUpperCase()}${_targetId != null ? " TO $_targetId" : ""}',
          style: GoogleFonts.dmMono(color: context.tokens.background, fontWeight: FontWeight.bold),
        ),
        backgroundColor: context.tokens.accent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final items = widget.state.getLocalMediaItems();
    final filtered = _query.isEmpty ? items : items.where((i) => i.title.toLowerCase().contains(_query.toLowerCase())).toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
            child: Row(
              children: [
                Icon(LucideIcons.playCircle, color: tokens.textPrimary, size: 20),
                const SizedBox(width: 16),
                Text('REMOTE MEDIA SELECT', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const Spacer(),
                IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          // Target Selector
          if (widget.state.activeSessions.isNotEmpty)
            Container(
              height: 60,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: Text('ALL NODES', style: GoogleFonts.dmMono(fontSize: 10)),
                    selected: _targetId == null,
                    onSelected: (v) => setState(() => _targetId = null),
                    backgroundColor: tokens.surface1,
                    selectedColor: tokens.textPrimary,
                    labelStyle: TextStyle(color: _targetId == null ? tokens.background : tokens.textPrimary),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  const SizedBox(width: 8),
                  ...widget.state.activeSessions.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.clientId.toUpperCase(), style: GoogleFonts.dmMono(fontSize: 10)),
                          selected: _targetId == s.clientId,
                          onSelected: (v) => setState(() => _targetId = v ? s.clientId : null),
                          backgroundColor: tokens.surface1,
                          selectedColor: tokens.textPrimary,
                          labelStyle: TextStyle(color: _targetId == s.clientId ? tokens.background : tokens.textPrimary),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                      )),
                ],
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'SEARCH MEDIA...',
                hintStyle: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 14),
                prefixIcon: Icon(LucideIcons.search, color: tokens.textMuted, size: 18),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.border.withValues(alpha: 0.15)), borderRadius: BorderRadius.zero),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.textPrimary), borderRadius: BorderRadius.zero),
              ),
            ),
          ),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('NO MEDIA MATCHES SIGNAL', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 12, letterSpacing: 2)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          leading: Icon(item.isVideo ? LucideIcons.video : LucideIcons.music, color: tokens.textPrimary, size: 18),
                          title: Text(item.title.toUpperCase(), style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _play(item),
                          trailing: Icon(LucideIcons.play, color: tokens.accent, size: 16),
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

class UniversalRemoteSheet extends StatelessWidget {
  const UniversalRemoteSheet({super.key, this.targetId});
  final String? targetId;

  void _cmd(BuildContext context, String type, String action, [dynamic value]) {
    context.read<ServerViewModel>().broadcastCommand(type, action, value: value, targetId: targetId);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
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
                      // Navigation Cluster
                      ServerQuickActionCard(label: 'BACK', icon: LucideIcons.chevronLeft, onTap: () => _cmd(context, 'nav', 'back')),
                      ServerQuickActionCard(label: 'UP', icon: LucideIcons.chevronUp, onTap: () => _cmd(context, 'nav', 'up')),
                      ServerQuickActionCard(label: 'HOME', icon: LucideIcons.home, onTap: () => _cmd(context, 'nav', 'home')),
            
                      ServerQuickActionCard(label: 'LEFT', icon: LucideIcons.chevronLeft, onTap: () => _cmd(context, 'nav', 'left')),
                      ServerQuickActionCard(label: 'ENTER', icon: LucideIcons.circle, onTap: () => _cmd(context, 'nav', 'enter')),
                      ServerQuickActionCard(label: 'RIGHT', icon: LucideIcons.chevronRight, onTap: () => _cmd(context, 'nav', 'right')),
            
                      ServerQuickActionCard(label: 'INFO', icon: LucideIcons.info, onTap: () => _cmd(context, 'nav', 'info')),
                      ServerQuickActionCard(label: 'DOWN', icon: LucideIcons.chevronDown, onTap: () => _cmd(context, 'nav', 'down')),
                      ServerQuickActionCard(label: 'MENU', icon: LucideIcons.menu, onTap: () => _cmd(context, 'nav', 'menu')),

                      // Media Cluster
                      ServerQuickActionCard(label: 'PREV', icon: LucideIcons.skipBack, onTap: () => _cmd(context, 'media', 'prev')),
                      ServerQuickActionCard(label: 'PLAY/PAUSE', icon: LucideIcons.play, onTap: () => _cmd(context, 'media', 'toggle_play')),
                      ServerQuickActionCard(label: 'NEXT', icon: LucideIcons.skipForward, onTap: () => _cmd(context, 'media', 'next')),
            
                      ServerQuickActionCard(label: '-10S', icon: LucideIcons.rewind, onTap: () => _cmd(context, 'media', 'seek', -10)),
                      ServerQuickActionCard(label: 'STOP', icon: LucideIcons.square, onTap: () => _cmd(context, 'media', 'stop')),
                      ServerQuickActionCard(label: '+10S', icon: LucideIcons.fastForward, onTap: () => _cmd(context, 'media', 'seek', 10)),

                      // System Cluster
                      ServerQuickActionCard(label: 'VOL UP', icon: LucideIcons.volume2, onTap: () => _cmd(context, 'system', 'volume_up')),
                      ServerQuickActionCard(label: 'MUTE', icon: LucideIcons.volumeX, onTap: () => _cmd(context, 'system', 'mute')),
                      ServerQuickActionCard(label: 'SHUTDOWN', icon: LucideIcons.power, onTap: () => _cmd(context, 'system', 'shutdown')),
            
                      ServerQuickActionCard(label: 'VOL DOWN', icon: LucideIcons.volume1, onTap: () => _cmd(context, 'system', 'volume_down')),
                      ServerQuickActionCard(label: 'SYNC ALL', icon: LucideIcons.refreshCw, onTap: () => _cmd(context, 'media', 'sync_all')),
                      ServerQuickActionCard(label: 'KILL ALL', icon: LucideIcons.skull, onTap: () => _cmd(context, 'system', 'shutdown_all')),
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
}

class _DashboardCLI extends StatefulWidget {
  const _DashboardCLI();

  @override
  State<_DashboardCLI> createState() => _DashboardCLIState();
}

class _DashboardCLIState extends State<_DashboardCLI> {
  final _ctrl = TextEditingController();
  final List<String> _log = [];

  void _exec(String input) {
    if (input.trim().isEmpty) return;
    final cmd = input.trim();
    setState(() => _log.add('> $cmd'));
    _ctrl.clear();

    final parts = cmd.split(' ');
    final action = parts[0].toLowerCase();
    String? targetId;
    final toIdx = parts.indexWhere((p) => p.startsWith('--to='));
    if (toIdx != -1) {
      targetId = parts[toIdx].split('=')[1].toUpperCase();
      parts.removeAt(toIdx);
    }

    final vm = context.read<ServerViewModel>();
    switch (action) {
      case '/play':
        final q = parts.skip(1).join(' ');
        vm.broadcastCommand('media', 'play', value: q, targetId: targetId);
        _log.add('MSG: BROADCASTING PLAY REQUEST [$q]${targetId != null ? ' TO [$targetId]' : ''}');
        break;
      case '/stop':
        vm.broadcastCommand('media', 'stop', targetId: targetId);
        _log.add('MSG: BROADCASTING STOP${targetId != null ? ' TO [$targetId]' : ''}');
        break;
      case '/kill':
        if (parts.length > 1 && parts[1] == '--all') {
          vm.broadcastCommand('system', 'shutdown');
          _log.add('MSG: BROADCASTING SHUTDOWN ALL');
        } else {
          vm.broadcastCommand('system', 'shutdown', targetId: targetId);
          _log.add('MSG: BROADCASTING SHUTDOWN${targetId != null ? ' TO [$targetId]' : ''}');
        }
        break;
      case '/home':
        vm.broadcastCommand('nav', 'home', targetId: targetId);
        _log.add('MSG: BROADCASTING HOME${targetId != null ? ' TO [$targetId]' : ''}');
        break;
      case '/sync':
        if (targetId != null) {
          vm
            ..broadcastCommand('media', 'set_sync_mode', value: 'slave')
            ..broadcastCommand('media', 'set_sync_mode', value: 'master', targetId: targetId);
          _log.add('MSG: SYNC MODE ENABLED. MASTER: [$targetId]');
        } else {
          _log.add('ERR: SYNC REQUIRES MASTER NODE [--to=clientId]');
        }
        break;
      case '/shift':
        String? fromId;
        final fromIdx = parts.indexWhere((p) => p.startsWith('--from='));
        if (fromIdx != -1) {
          fromId = parts[fromIdx].split('=')[1].toUpperCase();
          parts.removeAt(fromIdx);
        }
        if (fromId != null && targetId != null) {
          try {
            vm.teleport(fromId, targetId);
            _log.add('MSG: TELEPORTED SESSION FROM [$fromId] TO [$targetId]');
          } catch (_) {
            _log.add('ERR: SESSION NOT FOUND FOR [$fromId]');
          }
        } else {
          _log.add('ERR: SHIFT REQUIRES [--from=ID] AND [--to=ID]');
        }
        break;
      case '/curate':
        final vibe = parts.length > 1 ? parts[1].toLowerCase() : 'all';
        context.read<ServerViewModel>().curateStation(vibe);
        _log.add('MSG: AUTO-PILOT INITIATED [VIBE=$vibe]');
        break;
      case '/clear':
        setState(_log.clear);
        break;
      default:
        _log.add('ERR: UNKNOWN COMMAND [$action]');
    }

    if (_log.length > 3) _log.removeAt(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._log.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(l, style: GoogleFonts.dmMono(color: l.startsWith('ERR') ? tokens.error : tokens.textMuted, fontSize: 9)),
                )),
            Row(
              children: [
                Text('CMD>', style: GoogleFonts.dmMono(color: tokens.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'TYPE COMMAND...', hintStyle: TextStyle(fontSize: 10)),
                    onSubmitted: _exec,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
                      ...all.map((c) => _HistoryCard(record: c, isMobile: isMobile)),
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
      pinned: true,
      title: Text(
        'SYSTEM LOGS',
        style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w900, letterSpacing: 4),
      ),
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSearchField() {
    final tokens = context.tokens;
    return Focus(
      onFocusChange: (v) => handleTVFocusScroll(v, context),
      child: DecoratedBox(
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
                style: GoogleFonts.dmMono(color: tokens.textMuted),
              ),
            ),
            Expanded(
              child: TextField(
                style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'QUERY IP...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 20),
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
  const _HistoryCard({required this.record, required this.isMobile});
  final ConnectionRecord record;
  final bool isMobile;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Focus(
      onFocusChange: (v) => setState(() => _isFocused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isFocused ? tokens.textPrimary.withValues(alpha: 0.05) : tokens.surface1,
          border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
        ),
        child: Padding(
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
                    Text(
                      widget.record.ip,
                      style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${widget.record.network.toUpperCase()} // ${widget.record.time.hour}:${widget.record.time.minute}',
                      style: GoogleFonts.dmMono(fontSize: 9, color: tokens.textMuted),
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
      ),
    );
  }
}

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
    if (Platform.isWindows) {
      _path = r'C:\';
    } else if (Platform.isAndroid) {
      _path = '/storage/emulated/0';
    } else {
      _path = '/';
    }
    _load();
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
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.surface1,
        title: Text(_path, style: GoogleFonts.dmMono(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _path),
            child: Text('MOUNT', style: GoogleFonts.dmMono(color: tokens.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: Text('LEVEL UP', style: GoogleFonts.dmMono(color: tokens.textPrimary)),
            subtitle: Text('RETURN TO PARENT SIGNAL', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 8)),
            leading: Icon(LucideIcons.arrowUpLeft, color: tokens.textPrimary),
            onTap: () {
              final parent = Directory(_path).parent;
              if (parent.path != _path) {
                _path = parent.path;
                _load();
              }
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('ACCESS_ERROR: $_error', style: GoogleFonts.dmMono(color: tokens.error, fontSize: 10)),
            ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: tokens.accent))
                : _dirs.isEmpty && _error == null
                    ? Center(child: Text('NO SUBDIRECTORIES FOUND', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10)))
                    : ListView.builder(
                        itemCount: _dirs.length,
                        itemBuilder: (_, i) {
                          final name = p.basename(_dirs[i]);
                          return ListTile(
                            title: Text(name.toUpperCase(), style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14)),
                            subtitle: Text(_dirs[i], style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 8)),
                            leading: Icon(LucideIcons.folder, color: tokens.textMuted, size: 18),
                            onTap: () {
                              _path = _dirs[i];
                              _load();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

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

class _ToggleRow extends StatefulWidget {

  const _ToggleRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.isMobile,
    required this.onChanged,
    this.isLast = false,
  });
  final String label;
  final IconData icon;
  final bool value;
  final bool isMobile;
  final bool isLast;
  final Function(bool) onChanged;

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
                  child: Text(
                    widget.label,
                    style: GoogleFonts.dmMono(fontSize: 12, letterSpacing: 1, color: _isFocused ? tokens.background : (widget.value ? tokens.textPrimary : tokens.textMuted)),
                  ),
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

class _StationsTab extends StatefulWidget {
  const _StationsTab({required this.state, required this.pad, required this.isMobile});
  final ServerViewModel state;
  final double pad;
  final bool isMobile;

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
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
                color: tokens.surface1.withValues(alpha: 0.4),
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
                  child: DecoratedBox(
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
  const _StationCard({required this.station, required this.state, required this.isMobile});
  final BroadcastStation station;
  final ServerViewModel state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: station.isActive ? tokens.border.withValues(alpha: 0.3) : tokens.border.withValues(alpha: 0.05)),
        color: tokens.surface1.withValues(alpha: 0.4),
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
  const _BrutalistIconButton({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

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
  const _StationLiveStatus({required this.station});
  final BroadcastStation station;

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
        color: tokens.surface2.withValues(alpha: 0.5),
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
      color: tokens.surface2.withValues(alpha: 0.5),
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

class _LiveLogViewer extends StatelessWidget {
  const _LiveLogViewer({required this.state});
  final ServerViewModel state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final logs = state.serverLogs;
    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.8),
        border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TerminalHeader(title: 'LIVE_SIGNAL_LOGS', icon: LucideIcons.terminal),
          Expanded(
            child: logs.isEmpty
                ? Center(child: Text('WAITING FOR SIGNAL...', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        logs[i],
                        style: GoogleFonts.dmMono(color: tokens.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrafficMonitor extends StatefulWidget {
  const _TrafficMonitor({required this.state});
  final ServerViewModel state;

  @override
  State<_TrafficMonitor> createState() => _TrafficMonitorState();
}

class _TrafficMonitorState extends State<_TrafficMonitor> {
  final List<double> _history = List.filled(30, 0.0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _history
            ..removeAt(0)
            ..add(widget.state.currentSpeedMb);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final maxSpeed = _history.reduce((a, b) => a > b ? a : b).clamp(1.0, 1000.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.4),
        border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REAL-TIME BANDWIDTH',
            style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _history.map((h) {
                final hFactor = h / maxSpeed;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: (120 * hFactor).clamp(1.0, 120.0),
                      color: tokens.telemetry,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 MB/S', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 8)),
              Text('PEAK: ${maxSpeed.toStringAsFixed(1)} MB/S', style: GoogleFonts.dmMono(color: tokens.telemetry, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MountButton extends StatefulWidget {
  const _MountButton({required this.onMounted});
  final Function(String) onMounted;

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

class _DirRow extends StatefulWidget {
  const _DirRow({required this.path, required this.isLast, required this.onRemove});
  final String path;
  final bool isLast;
  final VoidCallback onRemove;

  @override
  State<_DirRow> createState() => _DirRowState();
}

class _DirRowState extends State<_DirRow> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    var count = 0;
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

class _BrutalistCheckbox extends StatelessWidget {
  const _BrutalistCheckbox({required this.value, required this.isFocused});
  final bool value;
  final bool isFocused;

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

List<String> _listSubdirectories(String rootPath) {
  try {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) return [];
    return dir.listSync(followLinks: false).whereType<Directory>().map((d) => d.path).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  } catch (_) {
    return [];
  }
}
