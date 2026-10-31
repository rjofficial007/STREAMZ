// presentation/mobile/mobile_selection_screen.dart
// ============================================================================
// STREAMZ — Mobile Interface Selection Gateway (Samsung-Style)
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
import 'package:streamz/presentation/mobile/mobile_selection_screen_tv.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_connection_badge.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';

class MobileSelectionScreen extends StatelessWidget {
  const MobileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (DS.isTV(context)) {
      return const MobileSelectionScreenTV();
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
        'Mobile',
        style: AppTextStyles.titleLarge.copyWith(
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
        Padding(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s8),
          child: AppConnectionBadge(
            hostIp: vm.targetIp,
            itemCount: vm.remoteMedia.length,
            connectionPhase: vm.connectionPhase,
          ),
        ),

        AppActionGrid(
          children: [
            AppActionCard(
              label: 'Browse media',
              icon: LucideIcons.tv,
              onTap: () => context.push('/client/mobile/ui'),
            ),
            AppActionCard(
              label: 'Files',
              icon: LucideIcons.folderOpen,
              onTap: () => context.push('/client/mobile/files'),
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
            description:
                'Active broadcasts from your network will appear here.',
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
