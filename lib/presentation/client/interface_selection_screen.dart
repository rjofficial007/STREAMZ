// presentation/client/interface_selection_screen.dart
// ============================================================================
// STREAMZ — Interface Selection Gateway
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/client_connection_phase.dart';
import 'package:streamz/domain/models/history_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/client/interface_selection_screen_tv.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
import 'package:streamz/presentation/shared/app_summary_components.dart';

class InterfaceSelectionScreen extends StatefulWidget {
  const InterfaceSelectionScreen({super.key});

  @override
  State<InterfaceSelectionScreen> createState() =>
      _InterfaceSelectionScreenState();
}

class _InterfaceSelectionScreenState extends State<InterfaceSelectionScreen> {
  bool _showAllHistory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientViewModel>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (DS.isTV(context)) {
      return const InterfaceSelectionScreenTV();
    }

    final vm = context.watch<ClientViewModel>();

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppSliverAppBar(context, vm),
            AppContentSliver(sliver: _buildBody(context, vm)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSliverAppBar(BuildContext context, ClientViewModel vm) {
    final tokens = context.tokens;
    return AppSliverAppBar(
      floating: true,
      pinned: true,
      titleSpacing: 0,
      leading: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              vm.disconnect();
              Navigator.pop(context);
              return null;
            },
          ),
        },
        child: Focus(
          onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
            vm.disconnect();
            Navigator.pop(context);
          }),
          child: AppBackButton(
            onPressed: () {
              vm.disconnect();
              Navigator.pop(context);
            },
          ),
        ),
      ),
      title: Text(
        'Choose an interface',
        style: AppTextStyles.titleLarge.copyWith(
          color: tokens.textPrimary,
          fontWeight: AppTextStyles.titleFontWeight,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            LucideIcons.refreshCw,
            size: 20,
            color: tokens.textPrimary,
          ),
          onPressed: () => vm.refresh(),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ClientViewModel vm) {
    final tokens = context.tokens;
    final recentHistory = _showAllHistory
        ? vm.localHistory
        : vm.localHistory.take(5).toList();
    return SliverList(
      delegate: SliverChildListDelegate([
        _GatewayAnalysisCard(vm: vm),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: AppActionCard(
                  label: 'TV',
                  icon: LucideIcons.tv,
                  onTap: () => context.push('/client/tv'),
                ),
              ),
              const SizedBox(width: DS.s12),
              Expanded(
                child: AppActionCard(
                  label: 'Mobile',
                  icon: LucideIcons.smartphone,
                  onTap: () => context.push('/client/mobile'),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              vm.disconnect();
              Navigator.pop(context);
            },
            icon: const Icon(LucideIcons.power, size: 16),
            label: const Text('Disconnect'),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Live stations',
            style: AppTextStyles.supporting.copyWith(
              color: tokens.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        if (vm.stations.isEmpty)
          _EmptySignalsPlaceholder()
        else
          ...vm.stations.map(
            (station) => AppListTileCard(
              title: station.name,
              subtitle: station.nowPlaying == null
                  ? 'Live station · Waiting for a track'
                  : 'Now playing · ${station.nowPlaying!.item.title}',
              icon: LucideIcons.radio,
              onTap: () => _tuneIn(context, vm, station),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Recently played',
            style: AppTextStyles.supporting.copyWith(
              color: tokens.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        if (vm.localHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No history yet',
              style: AppTextStyles.supporting.copyWith(
                color: tokens.textDisabled,
              ),
            ),
          )
        else
          ...recentHistory.map(
            (item) => AppListTileCard(
              title: item.media.title,
              subtitle: _historySubtitle(item),
              icon: item.media.isVideo ? LucideIcons.video : LucideIcons.music,
              trailingIcon: LucideIcons.play,
              onTap: () {
                context.push(
                  '/player',
                  extra: {
                    'items': [item.media],
                    'startIndex': 0,
                    'isPathBased': false,
                  },
                );
              },
            ),
          ),

        if (vm.localHistory.length > 5)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DS.s16),
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _showAllHistory = !_showAllHistory),
              icon: Icon(
                _showAllHistory
                    ? LucideIcons.chevronUp
                    : LucideIcons.chevronDown,
              ),
              label: Text(_showAllHistory ? 'Show less' : 'Show all history'),
            ),
          ),

        const SizedBox(height: 100),
      ]),
    );
  }

  Future<void> _tuneIn(
    BuildContext context,
    ClientViewModel vm,
    BroadcastStation station,
  ) async {
    final res = await vm.joinStation(station.id);
    if (res != null && context.mounted) {
      unawaited(
        context.push(
          '/player',
          extra: {
            'items': res.playlist,
            'startIndex': res.itemIndex,
            'isPathBased': false,
            'startOffset': res.position,
          },
        ),
      );
    }
  }

  String _historySubtitle(HistoryItem item) {
    final timestamp = item.timestamp;
    final time =
        '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    return 'Viewed ${timestamp.day}/${timestamp.month} · $time';
  }
}

class _GatewayAnalysisCard extends StatelessWidget {
  const _GatewayAnalysisCard({required this.vm});
  final ClientViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final phase = vm.connectionPhase;
    final phaseLabel = switch (phase) {
      ClientConnectionPhase.idle => 'Disconnected',
      ClientConnectionPhase.discovering => 'Finding server',
      ClientConnectionPhase.connecting => 'Connecting',
      ClientConnectionPhase.connected => 'Connected',
      ClientConnectionPhase.degraded => 'Sync issue',
      ClientConnectionPhase.reconnecting => 'Reconnecting',
      ClientConnectionPhase.failed => 'Connection failed',
    };
    final phaseColor = switch (phase) {
      ClientConnectionPhase.connected => tokens.success,
      ClientConnectionPhase.connecting ||
      ClientConnectionPhase.discovering ||
      ClientConnectionPhase.reconnecting => tokens.accent,
      _ => tokens.textMuted,
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DS.radius(20)),
        border: Border.all(color: tokens.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSummaryHeader(
            title: 'Connection overview',
            titleStyle: AppTextStyles.titleLarge.copyWith(
              color: tokens.textPrimary,
              fontWeight: AppTextStyles.titleFontWeight,
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DS.s12,
                vertical: DS.s8,
              ),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DS.radius(99)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    phase == ClientConnectionPhase.connected
                        ? LucideIcons.circleCheck
                        : LucideIcons.circleAlert,
                    size: 16,
                    color: phaseColor,
                  ),
                  const SizedBox(width: DS.s8),
                  Flexible(
                    child: Text(
                      phaseLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared media',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vm.remoteMedia.length} items',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Server address',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        vm.targetIp,
                        style: AppTextStyles.body.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _legend(
            'Streams',
            '${vm.stations.length} active',
            tokens.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, String value, Color color) =>
      AppSummaryLegend(label: label, value: value, markerColor: color);
}

class _EmptySignalsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const AppStateView(
    title: 'No live broadcasts',
    description: 'Active broadcasts from your server will appear here.',
    icon: LucideIcons.radioTower,
  );
}
