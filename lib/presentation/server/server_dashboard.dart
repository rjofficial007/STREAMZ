// presentation/server/server_dashboard.dart
// ============================================================================
// STREAMZ — Server Dashboard
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
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
import 'package:streamz/presentation/server/widgets/server_telemetry_tile.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_bottom_sheet.dart';
import 'package:streamz/presentation/shared/app_brand_icon.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
import 'package:streamz/presentation/shared/remote_input_relay_screen.dart';
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
    if (_currentPath == null) return 'Your server';
    if (_currentPath == 'filters') return 'Sharing options';
    if (_currentPath == 'directories') return 'Shared folders';
    if (_currentPath == 'stations') return 'Broadcasts';
    if (_currentPath == 'history') return 'Viewing history';
    if (_currentPath == 'traffic') return 'Network traffic';
    if (_currentPath == 'live_logs') return 'Live logs';
    return _currentPath!;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerViewModel>();
    final isMobile = DS.isMobile(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (!_goBack()) Navigator.pop(context);
        }
      },
      child: AppScaffold(
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppSliverAppBar(isMobile),
              ..._buildBodySlivers(isMobile, state),
            ],
          ),
        ),
        bottomNavigationBar: _currentPath == null
            ? const _DashboardCLI()
            : null,
      ),
    );
  }

  Widget _buildAppSliverAppBar(bool isMobile) {
    final showNav = _currentPath != null;
    final tokens = context.tokens;

    return AppSliverAppBar(
      floating: true,
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
                child: AppBackButton(onPressed: _goBack),
              ),
            )
          : null,
      automaticallyImplyLeading: false,
      title: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: DS.contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.only(left: showNav ? 0 : 16.0),
          child: Row(
            children: [
              if (!showNav) ...[
                AppBrandIcon(size: isMobile ? 28 : 36),
                const SizedBox(width: DS.s12),
              ],
              Expanded(
                child: Text(
                  _title,
                  style: AppTextStyles.style(
                    color: tokens.textPrimary,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: AppTextStyles.titleFontWeight,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Appearance settings',
          onPressed: () => context.push('/settings'),
          icon: const Icon(LucideIcons.settings2),
        ),
        const SizedBox(width: DS.s8),
      ],
    );
  }

  List<Widget> _buildBodySlivers(bool isMobile, ServerViewModel state) {
    if (_currentPath == null) {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: DS.contentMaxWidth),
              child: ServerEngineCard(state: state, isMobile: isMobile),
            ),
          ),
        ),

        // Primary Utility Grid (3 Columns)
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: DS.contentMaxWidth),
              child: AppActionGrid(
                padding: const EdgeInsets.all(16),
                children: [
                  AppActionCard(
                    label: 'Traffic',
                    icon: LucideIcons.barChart,
                    onTap: () => _navigateTo('traffic'),
                  ),
                  AppActionCard(
                    label: 'Live logs',
                    icon: LucideIcons.terminal,
                    onTap: () => _navigateTo('live_logs'),
                  ),
                  AppActionCard(
                    label: 'History',
                    icon: LucideIcons.history,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _ConnectionHistoryScreen(),
                      ),
                    ),
                  ),
                  AppActionCard(
                    label: 'Remote relay',
                    icon: LucideIcons.smartphoneNfc,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const RemoteInputRelayScreen(isServerMode: true),
                      ),
                    ),
                  ),
                  AppActionCard(
                    label: 'Remote control',
                    icon: LucideIcons.gamepad2,
                    onTap: () => showAppBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const UniversalRemoteSheet(),
                    ),
                  ),
                  AppActionCard(
                    label: 'Pair with QR',
                    icon: LucideIcons.qrCode,
                    onTap: () => _showQRSheet(context, state),
                  ),
                  AppActionCard(
                    label: 'Preview',
                    icon: LucideIcons.monitor,
                    onTap: () => _showPreviewSheet(context, state),
                  ),
                  AppActionCard(
                    label: 'Open web app',
                    icon: LucideIcons.globe,
                    onTap: () =>
                        launchUrl(Uri.parse('http://${state.serverIp}:8080')),
                  ),
                  AppActionCard(
                    label: 'Stations',
                    icon: LucideIcons.radio,
                    onTap: () => _navigateTo('stations'),
                  ),
                  AppActionCard(
                    label: 'Sharing options',
                    icon: LucideIcons.slidersHorizontal,
                    onTap: () => _navigateTo('filters'),
                  ),
                  AppActionCard(
                    label: 'Shared folders',
                    icon: LucideIcons.folderOpen,
                    onTap: () => _navigateTo('directories'),
                  ),
                  AppActionCard(
                    label: 'Media library',
                    icon: LucideIcons.playCircle,
                    onTap: () => _showRemoteMediaSheet(context, state),
                  ),
                  AppActionCard(
                    label: 'Create station',
                    icon: LucideIcons.wand2,
                    onTap: () => state.curateStation('all'),
                  ),
                  AppActionCard(
                    label: 'Sync clients',
                    icon: LucideIcons.refreshCw,
                    onTap: () {
                      if (state.activeSessions.isNotEmpty) {
                        final masterId = state.activeSessions.first.clientId;
                        sl<HttpServerService>().broadcast(
                          jsonEncode({
                            'type': 'media',
                            'action': 'set_sync_mode',
                            'value': 'master',
                            'targetId': masterId,
                          }),
                        );
                        sl<HttpServerService>().broadcast(
                          jsonEncode({
                            'type': 'media',
                            'action': 'set_sync_mode',
                            'value': 'slave',
                          }),
                        );
                      }
                    },
                  ),
                ],
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
              constraints: const BoxConstraints(maxWidth: DS.contentMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DS.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSheetHeader(
                      title: 'Choose folders to share',
                      subtitle: 'Connected devices can browse media in these folders.',
                      icon: LucideIcons.folderOpen,
                    ),
                    if (!kIsWeb)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DS.s24,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 180,
                            child: _MountButton(
                              onMounted: state.addSharedFolder,
                            ),
                          ),
                        ),
                      ),
                    if (state.sharedFolders.isEmpty)
                      const AppStateView(
                        title: 'No shared folders yet',
                        description: 'Add a folder to make its media available to connected devices.',
                        icon: LucideIcons.folderOpen,
                      )
                    else
                      ...state.sharedFolders.map(
                        (path) => _DirRow(
                          key: ValueKey(path),
                          path: path,
                          onRemove: () => state.removeSharedFolder(path),
                        ),
                      ),
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
              constraints: const BoxConstraints(maxWidth: DS.contentMaxWidth),
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
              constraints: const BoxConstraints(maxWidth: DS.contentMaxWidth),
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
              constraints: const BoxConstraints(maxWidth: DS.contentMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DS.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSheetHeader(
                      title: 'Content and privacy',
                      subtitle: 'Control the media and activity shared with connected devices.',
                      icon: LucideIcons.slidersHorizontal,
                    ),
                    _ToggleRow(
                      label: 'Share videos',
                      icon: LucideIcons.video,
                      value: state.shareVideos,
                      isMobile: isMobile,
                      onChanged: state.setShareVideos,
                    ),
                    _ToggleRow(
                      label: 'Share music',
                      icon: LucideIcons.music,
                      value: state.shareMusic,
                      isMobile: isMobile,
                      onChanged: state.setShareMusic,
                    ),
                    _ToggleRow(
                      label: 'Share images',
                      icon: LucideIcons.image,
                      value: state.shareImages,
                      isMobile: isMobile,
                      onChanged: state.setShareImages,
                    ),
                    _ToggleRow(
                      label: 'Private mode',
                      icon: LucideIcons.ghost,
                      value: state.zeroTrace,
                      isMobile: isMobile,
                      onChanged: state.setZeroTrace,
                    ),
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
          child: _StationsTab(state: state, isMobile: isMobile),
        ),
      ];
    }

    if (_currentPath == 'history') {
      return [_buildHistorySliver()];
    }

    return [const SliverToBoxAdapter(child: Center(child: Text('ERROR')))];
  }

  Widget _buildHistorySliver() {
    final history = sl<ServerRepository>().viewHistory;
    final tokens = context.tokens;

    if (history.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppStateView(
          title: 'No viewing history',
          description: 'Playback history from connected devices will appear here.',
          icon: LucideIcons.history,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = history[index];
          final time =
              '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}';
          return Padding(
            padding: const EdgeInsets.only(bottom: DS.s12),
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.all(DS.s16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tokens.surface2,
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      child: Icon(
                        item.media.isVideo
                            ? LucideIcons.video
                            : LucideIcons.music,
                        size: 20,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(width: DS.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.media.title,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: DS.s4),
                          Text(
                            '${item.clientIp} · $time',
                            style: AppTextStyles.supporting.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }, childCount: history.length),
      ),
    );
  }

  Widget _buildTelemetrySlivers(bool isMobile, ServerViewModel state) {
    final sessions = state.activeSessions;
    if (sessions.isEmpty) {
      return const SliverToBoxAdapter(
        child: AppStateView(
          title: 'No connected devices',
          description: 'Connect a device to see its live playback status here.',
          icon: LucideIcons.wifi,
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: DS.isDesktop(context)
            ? (MediaQuery.sizeOf(context).width - 800) / 2
            : 0,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final session = sessions[index];
          return DragTarget<String>(
            onAcceptWithDetails: (details) {
              final fromId = details.data;
              final targetId = session.clientId;
              if (fromId == targetId) return;

              state.teleport(fromId, targetId);
            },
            builder: (context, candidateData, rejectedData) =>
                ServerTelemetryTile(
                  session: session,
                  isMobile: isMobile,
                  isFirst: index == 0,
                  isTarget: candidateData.isNotEmpty,
                ),
          );
        }, childCount: sessions.length),
      ),
    );
  }

  void _showRemoteMediaSheet(BuildContext context, ServerViewModel state) {
    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RemoteMediaView(state: state),
    );
  }

  void _showQRSheet(BuildContext context, ServerViewModel state) {
    final tokens = context.tokens;
    showAppBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(DS.s24, 0, DS.s24, DS.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHeader(
              title: 'Pair a device',
              subtitle: 'Scan this code to connect to your server securely.',
              icon: LucideIcons.qrCode,
            ),
            const SizedBox(height: DS.s8),
            Container(
              width: 224,
              height: 224,
              padding: const EdgeInsets.all(DS.s12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DS.radiusMd),
                // [SECURITY B1] QR carries the pairing URL (token included) so
                // both the web UI and Flutter clients can authenticate to the
                // WS control plane after scanning.
                child: QrImageView(
                  data: state.pairingUrl,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: DS.s20),
            Container(
              constraints: const BoxConstraints(maxWidth: 420),
              width: double.infinity,
              padding: const EdgeInsets.all(DS.s16),
              decoration: BoxDecoration(
                color: tokens.surface2,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: Column(
                children: [
                  Text(
                    'Pairing code',
                    style: AppTextStyles.supporting.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: DS.s4),
                  SelectableText(
                    state.pairingToken,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading(
                      20,
                      spacing: 1,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DS.s8),
            Text(
              'You can also enter the server address and this code manually.',
              style: AppTextStyles.supporting.copyWith(color: tokens.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DS.s16),
          ],
        ),
      ),
    );
  }

  void _showPreviewSheet(BuildContext context, ServerViewModel state) {
    showAppBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: DS.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHeader(
              title: 'Choose an interface',
              subtitle: 'Preview the layout for each device type.',
              icon: LucideIcons.monitor,
            ),
            AppSheetOption(
              title: 'Mobile interface',
              subtitle: 'Touch-first layout for phones and tablets',
              icon: LucideIcons.smartphone,
              onTap: () {
                Navigator.pop(context);
                _safePreview(context, false, state);
              },
            ),
            AppSheetOption(
              title: 'TV interface',
              subtitle: 'Remote-friendly layout with D-pad focus',
              icon: LucideIcons.tv,
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

  Future<void> _safePreview(
    BuildContext context,
    bool isTV,
    ServerViewModel state,
  ) async {
    final tokens = context.tokens;
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            Center(child: CircularProgressIndicator(color: tokens.accent)),
      ),
    );
    // FIX: Use the DI singleton — every client screen watches this same instance.
    // The previous local ClientViewModel() connected an instance nobody else saw,
    // so preview always showed an empty library (and leaked its refresh timer).
    final vm = context.read<ClientViewModel>();
    try {
      final ok = await vm.connect(state.serverIp);
      if (context.mounted) Navigator.pop(context);
      if (ok && context.mounted) {
        unawaited(context.push('/client/interface'));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: tokens.error,
            content: Text(
              'PREVIEW CONNECTION FAILED: ${vm.connectionError ?? "UNKNOWN"}',
              style: AppTextStyles.style(color: tokens.background),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: tokens.error,
            content: Text(
              'PREVIEW ERROR: $e',
              style: AppTextStyles.style(color: tokens.background),
            ),
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
  late List<MediaItem> _items;
  String _query = '';
  String? _targetId;

  @override
  void initState() {
    super.initState();
    _items = widget.state.getLocalMediaItems();
  }

  @override
  void didUpdateWidget(covariant _RemoteMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _items = widget.state.getLocalMediaItems();
    }
  }

  void _play(MediaItem item) {
    sl<HttpServerService>().broadcast(
      jsonEncode({
        'type': 'media',
        'action': 'play',
        'value': item.toJson(),
        if (_targetId != null) 'targetId': _targetId,
      }),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'BROADCASTING: ${item.title.toUpperCase()}${_targetId != null ? " TO $_targetId" : ""}',
          style: AppTextStyles.style(
            color: context.tokens.background,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: context.tokens.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radius(12))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final query = _query.toLowerCase();
    final filtered = query.isEmpty
        ? _items
        : _items
              .where((item) => item.title.toLowerCase().contains(query))
              .toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      color: tokens.surface1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(
            title: 'Choose media',
            subtitle: 'Select content to play on a connected device.',
            icon: LucideIcons.playCircle,
            trailing: IconButton(
              tooltip: 'Close media selector',
              icon: const Icon(LucideIcons.x),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Target Selector
          if (widget.state.activeSessions.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: Text(
                      'ALL NODES',
                      style: AppTextStyles.caption.copyWith(),
                    ),
                    selected: _targetId == null,
                    onSelected: (v) => setState(() => _targetId = null),
                    backgroundColor: tokens.surface1,
                    selectedColor: tokens.textPrimary,
                    labelStyle: TextStyle(
                      color: _targetId == null
                          ? tokens.background
                          : tokens.textPrimary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radius(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...widget.state.activeSessions.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          s.clientId.toUpperCase(),
                          style: AppTextStyles.caption.copyWith(),
                        ),
                        selected: _targetId == s.clientId,
                        onSelected: (v) =>
                            setState(() => _targetId = v ? s.clientId : null),
                        backgroundColor: tokens.surface1,
                        selectedColor: tokens.textPrimary,
                        labelStyle: TextStyle(
                          color: _targetId == s.clientId
                              ? tokens.background
                              : tokens.textPrimary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.radius(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(DS.s16, DS.s8, DS.s16, DS.s16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: AppTextStyles.body.copyWith(color: tokens.textPrimary),
              decoration: InputDecoration(
                hintText: 'SEARCH MEDIA...',
                hintStyle: AppTextStyles.body.copyWith(color: tokens.textMuted),
                prefixIcon: Icon(
                  LucideIcons.search,
                  color: tokens.textMuted,
                  size: 18,
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'NO MEDIA MATCHES SIGNAL',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: DS.s24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return AppListTileCard(
                        title: item.title,
                        subtitle: item.isVideo ? 'Video' : 'Audio',
                        icon: item.isVideo ? LucideIcons.video : LucideIcons.music,
                        trailingIcon: LucideIcons.play,
                        onTap: () => _play(item),
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
    context.read<ServerViewModel>().broadcastCommand(
      type,
      action,
      value: value,
      targetId: targetId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: DS.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSheetHeader(
                title: 'Remote control',
                subtitle: targetId == null
                    ? 'Control playback and navigation on connected devices.'
                    : 'Control ${targetId!.toUpperCase()}.',
                icon: LucideIcons.gamepad2,
              ),
              AppActionGrid(
                padding: const EdgeInsets.all(16),
                children: [
                  // Navigation Cluster
                  AppActionCard(
                    label: 'BACK',
                    icon: LucideIcons.chevronLeft,
                    onTap: () => _cmd(context, 'nav', 'back'),
                  ),
                  AppActionCard(
                    label: 'UP',
                    icon: LucideIcons.chevronUp,
                    onTap: () => _cmd(context, 'nav', 'up'),
                  ),
                  AppActionCard(
                    label: 'HOME',
                    icon: LucideIcons.home,
                    onTap: () => _cmd(context, 'nav', 'home'),
                  ),

                  AppActionCard(
                    label: 'LEFT',
                    icon: LucideIcons.chevronLeft,
                    onTap: () => _cmd(context, 'nav', 'left'),
                  ),
                  AppActionCard(
                    label: 'ENTER',
                    icon: LucideIcons.circle,
                    onTap: () => _cmd(context, 'nav', 'enter'),
                  ),
                  AppActionCard(
                    label: 'RIGHT',
                    icon: LucideIcons.chevronRight,
                    onTap: () => _cmd(context, 'nav', 'right'),
                  ),

                  AppActionCard(
                    label: 'INFO',
                    icon: LucideIcons.info,
                    onTap: () => _cmd(context, 'nav', 'info'),
                  ),
                  AppActionCard(
                    label: 'DOWN',
                    icon: LucideIcons.chevronDown,
                    onTap: () => _cmd(context, 'nav', 'down'),
                  ),
                  AppActionCard(
                    label: 'MENU',
                    icon: LucideIcons.menu,
                    onTap: () => _cmd(context, 'nav', 'menu'),
                  ),

                  // Media Cluster
                  AppActionCard(
                    label: 'PREV',
                    icon: LucideIcons.skipBack,
                    onTap: () => _cmd(context, 'media', 'prev'),
                  ),
                  AppActionCard(
                    label: 'PLAY/PAUSE',
                    icon: LucideIcons.play,
                    onTap: () => _cmd(context, 'media', 'toggle_play'),
                  ),
                  AppActionCard(
                    label: 'NEXT',
                    icon: LucideIcons.skipForward,
                    onTap: () => _cmd(context, 'media', 'next'),
                  ),

                  AppActionCard(
                    label: '-10S',
                    icon: LucideIcons.rewind,
                    onTap: () => _cmd(context, 'media', 'seek', -10),
                  ),
                  AppActionCard(
                    label: 'STOP',
                    icon: LucideIcons.square,
                    onTap: () => _cmd(context, 'media', 'stop'),
                  ),
                  AppActionCard(
                    label: '+10S',
                    icon: LucideIcons.fastForward,
                    onTap: () => _cmd(context, 'media', 'seek', 10),
                  ),

                  // System Cluster
                  AppActionCard(
                    label: 'VOL UP',
                    icon: LucideIcons.volume2,
                    onTap: () => _cmd(context, 'system', 'volume_up'),
                  ),
                  AppActionCard(
                    label: 'MUTE',
                    icon: LucideIcons.volumeX,
                    onTap: () => _cmd(context, 'system', 'mute'),
                  ),
                  AppActionCard(
                    label: 'SHUTDOWN',
                    icon: LucideIcons.power,
                    onTap: () => _cmd(context, 'system', 'shutdown'),
                  ),

                  AppActionCard(
                    label: 'VOL DOWN',
                    icon: LucideIcons.volume1,
                    onTap: () => _cmd(context, 'system', 'volume_down'),
                  ),
                  AppActionCard(
                    label: 'SYNC ALL',
                    icon: LucideIcons.refreshCw,
                    onTap: () => _cmd(context, 'media', 'sync_all'),
                  ),
                  AppActionCard(
                    label: 'KILL ALL',
                    icon: LucideIcons.skull,
                    onTap: () => _cmd(context, 'system', 'shutdown_all'),
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
        _log.add(
          'MSG: BROADCASTING PLAY REQUEST [$q]${targetId != null ? ' TO [$targetId]' : ''}',
        );
        break;
      case '/stop':
        vm.broadcastCommand('media', 'stop', targetId: targetId);
        _log.add(
          'MSG: BROADCASTING STOP${targetId != null ? ' TO [$targetId]' : ''}',
        );
        break;
      case '/kill':
        if (parts.length > 1 && parts[1] == '--all') {
          vm.broadcastCommand('system', 'shutdown');
          _log.add('MSG: BROADCASTING SHUTDOWN ALL');
        } else {
          vm.broadcastCommand('system', 'shutdown', targetId: targetId);
          _log.add(
            'MSG: BROADCASTING SHUTDOWN${targetId != null ? ' TO [$targetId]' : ''}',
          );
        }
        break;
      case '/home':
        vm.broadcastCommand('nav', 'home', targetId: targetId);
        _log.add(
          'MSG: BROADCASTING HOME${targetId != null ? ' TO [$targetId]' : ''}',
        );
        break;
      case '/sync':
        if (targetId != null) {
          vm
            ..broadcastCommand('media', 'set_sync_mode', value: 'slave')
            ..broadcastCommand(
              'media',
              'set_sync_mode',
              value: 'master',
              targetId: targetId,
            );
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
        border: Border(
          top: BorderSide(color: tokens.border.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._log.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  l,
                  style: AppTextStyles.caption.copyWith(
                    color: l.startsWith('ERR')
                        ? tokens.error
                        : tokens.textMuted,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  'CMD>',
                  style: AppTextStyles.caption.copyWith(
                    color: tokens.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: AppTextStyles.caption.copyWith(
                      color: tokens.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'TYPE COMMAND...',
                      hintStyle: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
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
  State<_ConnectionHistoryScreen> createState() =>
      _ConnectionHistoryScreenState();
}

class _ConnectionHistoryScreenState extends State<_ConnectionHistoryScreen> {
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerViewModel>();
    final records = state.connectionHistory
        .where((c) => c.ip.contains(_query))
        .toList();
    final isMobile = DS.isMobile(context);

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: DS.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DS.s16,
                      DS.s8,
                      DS.s16,
                      0,
                    ),
                    child: _buildSearchField(),
                  ),
                ),
              ),
            ),
            if (records.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppStateView(
                  title: _query.isEmpty
                      ? 'No connection history'
                      : 'No matching connections',
                  description: _query.isEmpty
                      ? 'Completed connections will appear here.'
                      : 'Try another IP address or clear your search.',
                  icon: LucideIcons.history,
                  actionLabel: _query.isEmpty ? null : 'Clear search',
                  onAction: _query.isEmpty
                      ? null
                      : () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: DS.s32),
                sliver: SliverList.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) => _HistoryCard(
                    record: records[index],
                    isMobile: isMobile,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final tokens = context.tokens;
    return AppSliverAppBar(
      floating: true,
      pinned: true,
      title: Text(
        'Connection history',
        style: AppTextStyles.titleLarge.copyWith(
          color: tokens.textPrimary,
          fontWeight: AppTextStyles.titleFontWeight,
        ),
      ),
      leading: AppBackButton(onPressed: () => Navigator.pop(context)),
    );
  }

  Widget _buildSearchField() {
    final tokens = context.tokens;
    return Focus(
      onFocusChange: (v) => handleTVFocusScroll(v, context),
      child: TextField(
        style: AppTextStyles.body.copyWith(color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by IP address',
          prefixIcon: const Icon(LucideIcons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(LucideIcons.x),
                ),
        ),
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value.trim()),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record, required this.isMobile});
  final ConnectionRecord record;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: 4),
      child: AppCard(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? DS.s16 : DS.s20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                child: Icon(
                  LucideIcons.hardDrive,
                  color: tokens.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: DS.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.ip,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: DS.s4),
                    Text(
                      '${record.network} · ${record.time.hour.toString().padLeft(2, '0')}:${record.time.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.supporting.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DS.s12),
              Text(
                '${record.transferGB.toStringAsFixed(1)} GB',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
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
    final parentPath = Directory(_path).parent.path;
    final canGoUp = parentPath != _path;
    return AppScaffold(
      appBar: AppBar(
        leading: AppBackButton(onPressed: () => Navigator.pop(context)),
        title: Text(
          'Choose folder',
          style: AppTextStyles.titleLarge.copyWith(
            color: tokens.textPrimary,
            fontWeight: AppTextStyles.titleFontWeight,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add this folder',
            onPressed: () => Navigator.pop(context, _path),
            icon: const Icon(LucideIcons.folderPlus),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DS.s16, DS.s8, DS.s16, 0),
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.all(DS.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Current folder',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: DS.s4),
                    SelectableText(
                      _path,
                      style: AppTextStyles.supporting.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppListTileCard(
            title: 'Parent folder',
            subtitle: canGoUp ? parentPath : 'You are at the top level',
            icon: LucideIcons.arrowUpLeft,
            trailingIcon: null,
            onTap: canGoUp
                ? () {
                    _path = parentPath;
                    _load();
                  }
                : () {},
          ),
          if (_error != null)
            Expanded(
              child: AppStateView(
                kind: AppStateKind.error,
                title: 'Unable to read this folder',
                description: _error,
                icon: LucideIcons.folderX,
                actionLabel: 'Try again',
                onAction: _load,
              ),
            ),
          if (_error == null)
            Expanded(
              child: _loading
                  ? const AppStateView(
                      kind: AppStateKind.loading,
                      title: 'Loading folders',
                      description: 'Reading available folders…',
                    )
                  : _dirs.isEmpty
                  ? const AppStateView(
                      title: 'No subfolders found',
                      description: 'This folder does not contain any subfolders.',
                      icon: LucideIcons.folderOpen,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: DS.s24),
                      itemCount: _dirs.length,
                      itemBuilder: (_, index) {
                        final path = _dirs[index];
                        return AppListTileCard(
                          title: p.basename(path),
                          subtitle: path,
                          icon: LucideIcons.folder,
                          trailingIcon: null,
                          onTap: () {
                            _path = path;
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

class _ToggleRow extends StatefulWidget {
  const _ToggleRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.isMobile,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final bool value;
  final bool isMobile;
  final Function(bool) onChanged;

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DS.s24,
        vertical: DS.s4,
      ),
      child: Actions(
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
          onKeyEvent: (_, ev) =>
              handleTVSelectKey(ev, () => widget.onChanged(!widget.value)),
          child: Semantics(
            container: true,
            label: widget.label,
            checked: widget.value,
            child: InkWell(
              borderRadius: BorderRadius.circular(DS.radiusMd),
              onTap: () => widget.onChanged(!widget.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _isFocused
                      ? tokens.surface3
                      : tokens.surface1.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  border: Border.all(
                    color: _isFocused
                        ? tokens.focusColor
                        : tokens.border.withValues(alpha: 0.5),
                    width: _isFocused ? DS.focusWidth : 1,
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: DS.s16,
                  vertical: widget.isMobile ? DS.s12 : DS.s16,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.value ? tokens.accent : tokens.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: DS.s16),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w500,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    _ToggleIndicator(value: widget.value),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StationsTab extends StatefulWidget {
  const _StationsTab({
    required this.state,
    required this.isMobile,
  });
  final ServerViewModel state;
  final bool isMobile;

  @override
  State<_StationsTab> createState() => _StationsTabState();
}

class _StationsTabState extends State<_StationsTab> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final intro = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tokens.surface2,
            borderRadius: BorderRadius.circular(DS.radiusMd),
          ),
          child: Icon(LucideIcons.radio, color: tokens.textSecondary),
        ),
        const SizedBox(width: DS.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a station',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DS.s4),
              Text(
                'Build a playlist for a live broadcast.',
                style: AppTextStyles.supporting.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final createButton = AppButton(
      label: 'Create station',
      icon: LucideIcons.plus,
      isPrimary: false,
      height: 48,
      onTap: () => _showCreateStationDialog(context),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: DS.contentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DS.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(DS.s16),
                  child: widget.isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            intro,
                            const SizedBox(height: DS.s16),
                            createButton,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: intro),
                            const SizedBox(width: DS.s16),
                            SizedBox(width: 176, child: createButton),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: DS.s16),
            if (widget.state.stations.isEmpty)
              const AppStateView(
                title: 'No stations yet',
                description: 'Create a station to start a live broadcast.',
                icon: LucideIcons.radioTower,
              )
            else
              ...widget.state.stations.map(
                (s) => _StationCard(
                  key: ValueKey(s.id),
                  station: s,
                  state: widget.state,
                  isMobile: widget.isMobile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateStationDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final items = widget.state.getLocalMediaItems(shareImages: false);
    final selectedItems = <MediaItem>[];
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < DS.bpMobile;
    final dialogInset = isMobile ? 16.0 : 40.0;
    final dialogWidth = (width - dialogInset * 2 - 48).clamp(0.0, 800.0);
    final tokens = context.tokens;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.surface1,
          surfaceTintColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radiusLg),
            side: BorderSide(color: tokens.border.withValues(alpha: 0.6)),
          ),
          title: Text(
            'Create a station',
            style: AppTextStyles.heading(
              isMobile ? 22 : 28,
              spacing: -0.4,
              color: tokens.textPrimary,
            ),
          ),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: AppTextStyles.supporting.copyWith(
                    color: tokens.textPrimary,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Station name',
                    labelStyle: AppTextStyles.supporting.copyWith(
                      color: tokens.textMuted,
                    ),
                    filled: true,
                    fillColor: tokens.surface2,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: tokens.border.withValues(alpha: 0.45),
                      ),
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: tokens.accent, width: 1.5),
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: DS.s20),
                Text(
                  'Select media · ${selectedItems.length}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: DS.s12),
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              'No media is available to add.',
                              style: AppTextStyles.supporting.copyWith(
                                color: tokens.textMuted,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (ctx, i) {
                              final item = items[i];
                              final isSelected = selectedItems.contains(item);
                              return ListTile(
                                dense: true,
                                onTap: () => setDialogState(
                                  () => isSelected
                                      ? selectedItems.remove(item)
                                      : selectedItems.add(item),
                                ),
                                leading: Icon(
                                  item.isVideo
                                      ? LucideIcons.video
                                      : LucideIcons.music,
                                  color: isSelected
                                      ? tokens.accent
                                      : tokens.textMuted,
                                  size: 18,
                                ),
                                title: Text(
                                  item.title,
                                  style: AppTextStyles.body.copyWith(
                                    color: tokens.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Icon(
                                  isSelected
                                      ? LucideIcons.circleCheck
                                      : LucideIcons.circle,
                                  color: isSelected
                                      ? tokens.accent
                                      : tokens.textMuted,
                                  size: 18,
                                ),
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
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: (nameCtrl.text.isEmpty || selectedItems.isEmpty)
                  ? null
                  : () {
                      widget.state.createStation(nameCtrl.text, selectedItems);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Broadcast "${nameCtrl.text}" started.'),
                        ),
                      );
                    },
              icon: const Icon(LucideIcons.radio),
              label: const Text('Start broadcast'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    super.key,
    required this.station,
    required this.state,
    required this.isMobile,
  });
  final BroadcastStation station;
  final ServerViewModel state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final status = !station.isActive
        ? 'Inactive'
        : station.isPaused
        ? 'Paused'
        : 'Live';
    final statusColor = !station.isActive
        ? tokens.textMuted
        : station.isPaused
        ? tokens.warning
        : tokens.success;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DS.s4),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(isMobile ? DS.s16 : DS.s20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                    child: Icon(
                      LucideIcons.radio,
                      color: station.isActive
                          ? tokens.textPrimary
                          : tokens.textMuted,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: DS.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: DS.s4),
                        Text(
                          '${station.playlist.length} items · ${station.totalDuration.inMinutes} min',
                          style: AppTextStyles.supporting.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s12,
                      vertical: DS.s8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(DS.radiusLg),
                    ),
                    child: Text(
                      status,
                      style: AppTextStyles.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DS.s16,
                0,
                DS.s16,
                DS.s12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (station.isActive)
                    _StationActionButton(
                      icon: station.isPaused
                          ? LucideIcons.play
                          : LucideIcons.pause,
                      tooltip: station.isPaused ? 'Resume station' : 'Pause station',
                      onPressed: () => state.toggleStationPlayback(station.id),
                    ),
                  _StationActionButton(
                    icon: station.isActive
                        ? LucideIcons.square
                        : LucideIcons.play,
                    tooltip: station.isActive ? 'Stop station' : 'Start station',
                    onPressed: () => state.toggleStationActive(station.id),
                  ),
                  _StationActionButton(
                    icon: LucideIcons.trash2,
                    tooltip: 'Remove station',
                    color: tokens.error,
                    onPressed: () => state.removeStation(station.id),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DS.s16,
                0,
                DS.s16,
                DS.s16,
              ),
              child: _StationLiveStatus(station: station),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationActionButton extends StatelessWidget {
  const _StationActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (focused) {
      if (focused) handleTVFocusScroll(focused, context);
    },
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: context.tokens.surface2,
        foregroundColor: color ?? context.tokens.textSecondary,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    ),
  );
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
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _StationLiveStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.station.isActive != widget.station.isActive ||
        oldWidget.station.isPaused != widget.station.isPaused) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.station.isActive && !widget.station.isPaused) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
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
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(DS.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DS.s16),
          child: Row(
            children: [
              Icon(LucideIcons.radioTower, color: tokens.textMuted, size: 18),
              const SizedBox(width: DS.s8),
              Text(
                'Station is inactive',
                style: AppTextStyles.supporting.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final playbackState = sl<StationService>().getPlaybackState(widget.station);
    if (playbackState == null) return const SizedBox.shrink();

    final item = playbackState.item;
    final totalMs = item.duration * 1000;
    final progress = totalMs > 0
        ? playbackState.position.inMilliseconds / totalMs
        : 0.0;
    final isPaused = widget.station.isPaused;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(DS.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DS.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPaused ? LucideIcons.pause : LucideIcons.radio,
                  color: isPaused ? tokens.warning : tokens.success,
                  size: 16,
                ),
                const SizedBox(width: DS.s8),
                Text(
                  isPaused ? 'Paused' : 'Live now',
                  style: AppTextStyles.caption.copyWith(
                    color: isPaused ? tokens.warning : tokens.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: Text(
                    item.title,
                    style: AppTextStyles.supporting.copyWith(
                      color: tokens.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(DS.radiusSm),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: tokens.background,
                valueColor: AlwaysStoppedAnimation(
                  isPaused ? tokens.warning : tokens.accent,
                ),
              ),
            ),
          ],
        ),
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
    return AppCard(
      child: SizedBox(
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetHeader(
              title: 'Recent server activity',
              subtitle: 'Events from this server, newest first',
              icon: LucideIcons.terminal,
            ),
            Expanded(
              child: logs.isEmpty
                  ? const AppStateView(
                      title: 'Waiting for logs',
                      description: 'New server activity will appear here.',
                      icon: LucideIcons.terminal,
                    )
                  : SelectionArea(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          DS.s24,
                          0,
                          DS.s24,
                          DS.s24,
                        ),
                        itemCount: logs.length,
                        itemBuilder: (_, index) => Padding(
                          padding: const EdgeInsets.only(bottom: DS.s8),
                          child: Text(
                            logs[index],
                            style: AppTextStyles.supporting.copyWith(
                              color: tokens.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
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
    final peakSpeed = _history.reduce((a, b) => a > b ? a : b);
    final scaleMax = peakSpeed.clamp(1.0, 1000.0);
    final currentSpeed = widget.state.currentSpeedMb;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(
            title: 'Live throughput',
            subtitle: 'Live throughput over the last 30 seconds',
            icon: LucideIcons.barChart,
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DS.s12,
                vertical: DS.s8,
              ),
              decoration: BoxDecoration(
                color: tokens.surface2,
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              child: Text(
                '${currentSpeed.toStringAsFixed(1)} MB/s',
                style: AppTextStyles.body.copyWith(
                  color: tokens.telemetry,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DS.s24,
              0,
              DS.s24,
              DS.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 144,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _history.map((speed) {
                      final height = (144 * speed / scaleMax).clamp(2.0, 144.0);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            height: height,
                            decoration: BoxDecoration(
                              color: tokens.telemetry.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(DS.radius(3)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: DS.s12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '30 seconds ago',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    Text(
                      'Peak ${peakSpeed.toStringAsFixed(1)} MB/s',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.telemetry,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Now',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MountButton extends StatelessWidget {
  const _MountButton({required this.onMounted});
  final ValueChanged<String> onMounted;

  Future<void> _pickFolder(BuildContext context) async {
    final picked = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FolderPickerScreen()),
    );
    if (context.mounted && picked is String) onMounted(picked);
  }

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (focused) {
      if (focused) handleTVFocusScroll(focused, context);
    },
    child: AppButton(
      label: 'Add folder',
      icon: LucideIcons.folderPlus,
      isPrimary: false,
      height: 48,
      onTap: () => _pickFolder(context),
    ),
  );
}

class _DirRow extends StatefulWidget {
  const _DirRow({super.key, required this.path, required this.onRemove});
  final String path;
  final VoidCallback onRemove;

  @override
  State<_DirRow> createState() => _DirRowState();
}

class _DirRowState extends State<_DirRow> {
  Future<int>? _itemCount;

  @override
  void initState() {
    super.initState();
    _loadItemCount();
  }

  @override
  void didUpdateWidget(covariant _DirRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _loadItemCount();
  }

  void _loadItemCount() {
    _itemCount = kIsWeb ? null : compute(_countDirectoryEntries, widget.path);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DS.s24,
        vertical: DS.s4,
      ),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(DS.s16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                child: Icon(
                  LucideIcons.folder,
                  color: tokens.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: DS.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.path,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: DS.s4),
                    if (kIsWeb)
                      Text(
                        'Shared with connected devices',
                        style: AppTextStyles.supporting.copyWith(
                          color: tokens.textMuted,
                        ),
                      )
                    else
                      FutureBuilder<int>(
                        future: _itemCount,
                        builder: (context, snapshot) => Text(
                          snapshot.hasData
                              ? '${snapshot.data} items'
                              : snapshot.hasError
                              ? 'Shared with connected devices'
                              : 'Counting items…',
                          style: AppTextStyles.supporting.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Focus(
                onFocusChange: (focused) {
                  if (focused) handleTVFocusScroll(focused, context);
                },
                child: IconButton(
                  tooltip: 'Remove shared folder',
                  onPressed: widget.onRemove,
                  icon: Icon(
                    LucideIcons.x,
                    color: tokens.textMuted,
                    size: 20,
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

class _ToggleIndicator extends StatelessWidget {
  const _ToggleIndicator({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: value ? tokens.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(DS.radius(8)),
        border: Border.all(
          color: value ? tokens.accent : tokens.borderStrong,
          width: 1.5,
        ),
      ),
      child: value
          ? Center(
              child: Icon(
                LucideIcons.check,
                size: 16,
                color: tokens.textPrimary,
              ),
            )
          : null,
    );
  }
}

List<String> _listSubdirectories(String rootPath) {
  final dir = Directory(rootPath);
  if (!dir.existsSync()) return [];
  return dir
      .listSync(followLinks: false)
      .whereType<Directory>()
      .map((d) => d.path)
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

Future<int> _countDirectoryEntries(String path) async {
  var count = 0;
  await for (final _ in Directory(path).list(followLinks: false)) {
    count++;
  }
  return count;
}
