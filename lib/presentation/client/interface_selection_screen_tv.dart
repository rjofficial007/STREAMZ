// presentation/client/interface_selection_screen_tv.dart
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

class InterfaceSelectionScreenTV extends StatefulWidget {
  const InterfaceSelectionScreenTV({super.key});

  @override
  State<InterfaceSelectionScreenTV> createState() =>
      _InterfaceSelectionScreenTVState();
}

class _InterfaceSelectionScreenTVState
    extends State<InterfaceSelectionScreenTV> {
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
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return AppScaffold(
      body: Stack(
        children: [
          // Main Content
          SafeArea(
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
                              children: [
                                Expanded(
                                  child: _TVGatewayCard(
                                    label: 'TV interface',
                                    subLabel: 'Designed for a large screen',
                                    icon: LucideIcons.tv,
                                    onTap: () => context.push('/client/tv'),
                                    autofocus: true,
                                  ),
                                ),
                                const SizedBox(width: DS.s24),
                                Expanded(
                                  child: _TVGatewayCard(
                                    label: 'Mobile interface',
                                    subLabel:
                                        'A touch-friendly browsing layout',
                                    icon: LucideIcons.smartphone,
                                    onTap: () => context.push('/client/mobile'),
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  vm.disconnect();
                                  Navigator.pop(context);
                                },
                                icon: const Icon(LucideIcons.power),
                                label: const Text('Disconnect'),
                              ),
                            ),
                            SizedBox(
                              height: (size.height * 0.05).clamp(24.0, 48.0),
                            ),
                            Text(
                              'Live streams',
                              style: AppTextStyles.heading(
                                (size.width * 0.016).clamp(20.0, 30.0),
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: DS.s16),
                            if (vm.stations.isEmpty)
                              _buildEmptySignals(context)
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: size.width > 1200 ? 2 : 1,
                                      mainAxisExtent: (104 * textScale).clamp(
                                        104.0,
                                        168.0,
                                      ),
                                      crossAxisSpacing: DS.s24,
                                      mainAxisSpacing: DS.s16,
                                    ),
                                itemCount: vm.stations.length,
                                itemBuilder: (context, index) {
                                  final station = vm.stations[index];
                                  return AppListTileCard(
                                    title: station.name,
                                    subtitle: station.nowPlaying == null
                                        ? 'Live station · Waiting for a track'
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
        ],
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
                  'Choose an interface',
                  style: AppTextStyles.heading(
                    (size.width * 0.025).clamp(24.0, 38.0),
                    color: context.tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: DS.s4),
                Text(
                  'Pick the layout that works best on this screen.',
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

  Widget _buildEmptySignals(BuildContext context) => const AppStateView(
    title: 'No live broadcasts yet',
    description: 'Active streams from this server will appear here.',
    icon: LucideIcons.radioTower,
  );
}

class _TVGatewayCard extends StatefulWidget {
  const _TVGatewayCard({
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
  State<_TVGatewayCard> createState() => _TVGatewayCardState();
}

class _TVGatewayCardState extends State<_TVGatewayCard> {
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
    );
  }
}
