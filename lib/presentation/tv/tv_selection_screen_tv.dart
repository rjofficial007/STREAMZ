// presentation/tv/tv_selection_screen_tv.dart
// ============================================================================
// STREAMZ — TV interface selection
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

class TVSelectionScreenTV extends StatefulWidget {
  const TVSelectionScreenTV({super.key});

  @override
  State<TVSelectionScreenTV> createState() => _TVSelectionScreenTVState();
}

class _TVSelectionScreenTVState extends State<TVSelectionScreenTV> {
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
    final horizontalPad = DS.hPad(size.width);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, vm),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: DS.contentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: DS.s24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _TVModeCard(
                                label: 'TV dashboard',
                                subLabel:
                                    'Browse your library with a TV-focused layout',
                                icon: LucideIcons.tv,
                                onTap: () => context.push('/client/tv/home'),
                                autofocus: true,
                              ),
                            ),
                            const SizedBox(width: DS.s24),
                            Expanded(
                              child: _TVModeCard(
                                label: 'Browse files',
                                subLabel: 'Open folders and choose media',
                                icon: LucideIcons.folderOpen,
                                onTap: () => context.push('/client/tv/files'),
                              ),
                            ),
                            const SizedBox(width: DS.s24),
                            Expanded(
                              child: _TVModeCard(
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
                        SizedBox(
                          height: (size.height * 0.05).clamp(24.0, 48.0),
                        ),
                        Text(
                          'Live streams',
                          style: AppTextStyles.heading(
                            (size.width * 0.016).clamp(20.0, 30.0),
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
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: size.width > 1200 ? 2 : 1,
                                  childAspectRatio: size.width > 1200 ? 4 : 5,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ClientViewModel vm) {
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = DS.hPad(size.width);
    final verticalPad = (size.height * 0.04).clamp(16.0, 40.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPad,
        verticalPad,
        horizontalPad,
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
                  'TV experience',
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
    title: 'No live broadcasts',
    description: 'Active broadcasts from your network will appear here.',
    icon: LucideIcons.radioTower,
  );
}

class _TVModeCard extends StatefulWidget {
  const _TVModeCard({
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
  State<_TVModeCard> createState() => _TVModeCardState();
}

class _TVModeCardState extends State<_TVModeCard> {
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
            child: Padding(
              padding: const EdgeInsets.all(DS.s20),
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
                      style: AppTextStyles.style(
                        color: tokens.textPrimary,
                        fontSize: (size.width * 0.018).clamp(20.0, 30.0),
                        fontWeight: AppTextStyles.titleFontWeight,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: DS.s4),
                    Text(
                      widget.subLabel,
                      style: AppTextStyles.style(
                        color: tokens.textMuted,
                        fontSize: (size.width * 0.009).clamp(12.0, 15.0),
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
      ),
    );
  }
}
