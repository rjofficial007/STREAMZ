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
import 'package:streamz/domain/models/history_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/client/interface_selection_screen_tv.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';

class InterfaceSelectionScreen extends StatefulWidget {
  const InterfaceSelectionScreen({super.key});

  @override
  State<InterfaceSelectionScreen> createState() =>
      _InterfaceSelectionScreenState();
}

class _InterfaceSelectionScreenState extends State<InterfaceSelectionScreen> {
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
    return SliverList(
      delegate: SliverChildListDelegate([
        _GatewayAnalysisCard(vm: vm),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: AppActionCard(
                    label: 'TV',
                    icon: LucideIcons.tv,
                    onTap: () => context.push('/client/tv'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppActionCard(
                    label: 'Mobile',
                    icon: LucideIcons.smartphone,
                    onTap: () => context.push('/client/mobile'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppActionCard(
                    label: 'Disconnect',
                    icon: LucideIcons.power,
                    onTap: () {
                      vm.disconnect();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Live streams',
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
            'Recently viewed',
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
          ...vm.localHistory.map(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Connection overview',
                style: AppTextStyles.titleLarge.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: AppTextStyles.titleFontWeight,
                ),
              ),
              _BlinkingDot(isOnline: vm.isConnected),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vm.isConnected ? 'Connected' : 'Disconnected',
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
                        vm.targetIp.toUpperCase(),
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
          Stack(
            children: [
              Container(height: 8, color: tokens.surface2),
              if (vm.isConnected)
                FractionallySizedBox(
                  widthFactor: 1.0, // Solid bar for stable connection
                  child: Container(height: 8, color: tokens.accent),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _legend(
                  context,
                  'Streams',
                  '${vm.stations.length} active',
                  tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _legend(
                  context,
                  'Network',
                  'Ready',
                  tokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final tokens = context.tokens;
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: tokens.textMuted),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _EmptySignalsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15)),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.radioTower, size: 40, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text(
              'NO LIVE BROADCASTS',
              style: AppTextStyles.caption.copyWith(
                color: tokens.textMuted,
                letterSpacing: 0.8,
              ),
            ),
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

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (!widget.isOnline) {
      return Container(width: 8, height: 8, color: tokens.textDisabled);
    }
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
