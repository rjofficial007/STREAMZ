// presentation/tv/tv_selection_screen.dart
// ============================================================================
// STREAMZ — TV Interface Selection Gateway (Samsung-Style)
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
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
import 'package:streamz/presentation/tv/tv_selection_screen_tv.dart';

class TVSelectionScreen extends StatelessWidget {
  const TVSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (DS.isTV(context)) {
      return const TVSelectionScreenTV();
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
              Navigator.pop(context);
              return null;
            },
          ),
        },
        child: Focus(
          onKeyEvent: (_, ev) =>
              handleTVSelectKey(ev, () => Navigator.pop(context)),
          child: AppBackButton(onPressed: () => Navigator.pop(context)),
        ),
      ),
      title: Text(
        'TV',
        style: AppTextStyles.sectionTitle.copyWith(
          color: tokens.textPrimary,
          fontWeight: AppTextStyles.titleFontWeight,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ClientViewModel vm) {
    final tokens = context.tokens;
    return SliverList(
      delegate: SliverChildListDelegate([
        _SessionAnalysisCard(vm: vm, mode: 'TV'),

        AppActionGrid(
          children: [
            AppActionCard(
              label: 'Browse media',
              icon: LucideIcons.tv,
              onTap: () => context.push('/client/tv/home'),
            ),
            AppActionCard(
              label: 'Files',
              icon: LucideIcons.folderOpen,
              onTap: () => context.push('/client/tv/files'),
            ),
            AppActionCard(
              label: 'Disconnect',
              icon: LucideIcons.power,
              onTap: () {
                vm.disconnect();
                Navigator.pop(context);
              },
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s24, DS.s16, DS.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live streams',
                style: AppTextStyles.heading(
                  20,
                  spacing: -0.3,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: DS.s4),
              Text(
                'Join a live broadcast on your network.',
                style: AppTextStyles.supporting.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ),

        if (vm.stations.isEmpty)
          const AppStateView(
            title: 'No live broadcasts',
            description: 'Active broadcasts from your network will appear here.',
            icon: LucideIcons.radioTower,
          )
        else
          ...vm.stations.map(
            (station) => AppListTileCard(
              title: station.name,
              subtitle: station.nowPlaying == null
                  ? 'Waiting for a track'
                  : 'Now playing · ${station.nowPlaying!.item.title}',
              icon: LucideIcons.radio,
              onTap: () => _tuneIn(context, vm, station),
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
}

class _SessionAnalysisCard extends StatelessWidget {
  const _SessionAnalysisCard({required this.vm, required this.mode});
  final ClientViewModel vm;
  final String mode;

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
                      'Interface',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode,
                      style: AppTextStyles.body.copyWith(
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
                  widthFactor: 1.0,
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
                  'Library',
                  '${vm.remoteMedia.length} items',
                  tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _legend(context, 'Network', 'Connected', tokens.success),
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
