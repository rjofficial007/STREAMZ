// presentation/mobile/mobile_selection_screen_tv.dart
// ============================================================================
// STREAMZ — Mobile interface selection on TV
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
import 'package:streamz/presentation/shared/app_connection_badge.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';

class MobileSelectionScreenTV extends StatefulWidget {
  const MobileSelectionScreenTV({super.key});

  @override
  State<MobileSelectionScreenTV> createState() =>
      _MobileSelectionScreenTVState();
}

class _MobileSelectionScreenTVState extends State<MobileSelectionScreenTV> {
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final sidePadding = DS.hPad(size.width);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, vm),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: DS.s24),
                    Row(
                      children: [
                        Expanded(
                          child: _TVMobileModeCard(
                            label: 'Mobile dashboard',
                            subLabel:
                                'Browse your library with a touch-friendly layout',
                            icon: LucideIcons.tv,
                            onTap: () => context.push('/client/mobile/ui'),
                            autofocus: true,
                          ),
                        ),
                        const SizedBox(width: DS.s24),
                        Expanded(
                          child: _TVMobileModeCard(
                            label: 'Browse files',
                            subLabel: 'Open folders and choose media',
                            icon: LucideIcons.folderOpen,
                            onTap: () => context.push('/client/mobile/files'),
                          ),
                        ),
                        const SizedBox(width: DS.s24),
                        Expanded(
                          child: _TVMobileModeCard(
                            label: 'Disconnect',
                            subLabel: 'Leave the connected server',
                            icon: LucideIcons.power,
                            onTap: () {
                              vm.disconnect();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DS.s48),
                    Text(
                      'Live streams',
                      style: AppTextStyles.heading(
                        24,
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
                    const SizedBox(height: DS.s16),
                    if (vm.stations.isEmpty)
                      _buildEmptySignals()
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: DS.responsiveColumns(
                            context,
                            availableWidth: size.width - 2 * sidePadding,
                            spacing: DS.s24,
                            minTileWidth: 320,
                            maxColumns: 4,
                          ),
                          childAspectRatio: 4,
                          crossAxisSpacing: DS.s24,
                          mainAxisSpacing: DS.s16,
                        ),
                        itemCount: vm.stations.length,
                        itemBuilder: (context, index) {
                          final station = vm.stations[index];
                          return AppListTileCard(
                            title: station.name,
                            subtitle: station.nowPlaying == null
                                ? 'Waiting for a track'
                                : 'Now playing · ${station.nowPlaying!.item.title}',
                            icon: LucideIcons.radio,
                            onTap: () => _tuneIn(context, vm, station),
                          );
                        },
                      ),
                    const SizedBox(height: DS.s80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ClientViewModel vm) {
    final size = MediaQuery.sizeOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DS.hPad(size.width),
        (size.height * 0.04).clamp(16.0, 40.0),
        DS.hPad(size.width),
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobile experience',
                  style: AppTextStyles.heading(
                    (size.width * 0.025).clamp(24.0, 38.0),
                    color: context.tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: DS.s4),
                Text(
                  'Choose how to browse and play your shared media.',
                  style: AppTextStyles.body.copyWith(
                    color: context.tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DS.s16),
          AppConnectionBadge(
            hostIp: vm.targetIp,
            itemCount: vm.remoteMedia.length,
            connectionPhase: vm.connectionPhase,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySignals() => const AppStateView(
    title: 'No live broadcasts yet',
    description: 'Active streams from this server will appear here.',
    icon: LucideIcons.radioTower,
  );
}

class _TVMobileModeCard extends StatefulWidget {
  const _TVMobileModeCard({
    required this.label,
    required this.subLabel,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
  });
  final String label;
  final String subLabel;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_TVMobileModeCard> createState() => _TVMobileModeCardState();
}

class _TVMobileModeCardState extends State<_TVMobileModeCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused ? tokens.surface3 : tokens.surface1;
    final borderColor = _isFocused ? tokens.focusColor : tokens.border;
    final size = MediaQuery.sizeOf(context);

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) {
        setState(() => _isFocused = v);
        if (v) handleTVFocusScroll(v, context);
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            constraints: BoxConstraints(
              minHeight: (size.height * 0.3).clamp(180.0, 300.0).toDouble(),
            ),
            padding: const EdgeInsets.all(DS.s20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(DS.radius(24)),
              border: Border.all(color: borderColor, width: _isFocused ? 3 : 1),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: tokens.focusShadow.withValues(alpha: 0.12),
                        blurRadius: 24,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      borderRadius: BorderRadius.circular(DS.radius(20)),
                    ),
                    child: Icon(
                      widget.icon,
                      color: _isFocused
                          ? tokens.textPrimary
                          : tokens.textSecondary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: DS.s20),
                  Text(
                    widget.label,
                    style: AppTextStyles.headline.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: AppTextStyles.titleFontWeight,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DS.s4),
                  Text(
                    widget.subLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: tokens.textMuted,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
