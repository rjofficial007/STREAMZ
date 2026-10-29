// presentation/mobile/mobile_selection_screen_tv.dart
// ============================================================================
// STREAMZ — Mobile Interface Selection Gateway (NOC Dashboard)
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

    return AppScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, vm),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: DS.s80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: DS.s24),
                    Row(
                      children: [
                        Expanded(
                          child: _TVMobileModeCard(
                            label: 'MODERN UI',
                            subLabel: 'TOUCH-FRIENDLY DASHBOARD',
                            code: 'MOB-01',
                            icon: LucideIcons.tv,
                            onTap: () => context.push('/client/mobile/ui'),
                            autofocus: true,
                          ),
                        ),
                        const SizedBox(width: DS.s24),
                        Expanded(
                          child: _TVMobileModeCard(
                            label: 'FILE SYSTEM',
                            subLabel: 'RAW ASSET NAVIGATION',
                            code: 'MOB-02',
                            icon: LucideIcons.folderOpen,
                            onTap: () =>
                                context.push('/client/mobile/files'),
                          ),
                        ),
                        const SizedBox(width: DS.s24),
                        Expanded(
                          child: _TVMobileModeCard(
                            label: 'DISCONNECT',
                            subLabel: 'TERMINATE SESSION',
                            code: 'CMD-99',
                            icon: LucideIcons.power,
                            isWarning: true,
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
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
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ClientViewModel vm) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s80, vertical: DS.s40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOBILE INTERFACE // SESSION ANALYSIS',
                  style: AppTextStyles.style(
                    color: tokens.textPrimary,
                    fontSize: 32,
                    fontWeight: AppTextStyles.titleFontWeight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: DS.s8),
                Container(height: 2, width: 200, color: tokens.accent),
              ],
            ),
          ),
          const _StatusModule(label: 'ACTIVE MODE', value: 'MOBILE MODE'),
          const SizedBox(width: DS.s48),
          _StatusModule(label: 'HOST IP', value: vm.targetIp.toUpperCase()),
          const SizedBox(width: DS.s48),
          _StatusModule(
            label: 'ASSETS',
            value: '${vm.remoteMedia.length} INDEXED',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s80, vertical: DS.s40),
      child: Row(
        children: [
          Text(
            'SIGNAL ANALYSIS: OPTIMAL // LATENCY: LOW // ENCRYPTION: NONE',
            style: AppTextStyles.caption.copyWith(
              color: tokens.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          const _BlinkingDotTV(),
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

class _StatusModule extends StatelessWidget {
  const _StatusModule({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: tokens.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TVMobileModeCard extends StatefulWidget {
  const _TVMobileModeCard({
    required this.label,
    required this.subLabel,
    required this.code,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
    this.isWarning = false,
  });
  final String label;
  final String subLabel;
  final String code;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;
  final bool isWarning;

  @override
  State<_TVMobileModeCard> createState() => _TVMobileModeCardState();
}

class _TVMobileModeCardState extends State<_TVMobileModeCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused ? tokens.surface3 : tokens.surface1;
    final borderColor = _isFocused
        ? (widget.isWarning ? tokens.error : tokens.accent)
        : tokens.border;

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
            height: 240,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(DS.radius(24)),
              border: Border.all(color: borderColor, width: _isFocused ? 4 : 1),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: (widget.isWarning ? tokens.error : tokens.accent)
                            .withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SYS_TYPE // ${widget.code}',
                    style: AppTextStyles.caption.copyWith(
                      color: _isFocused
                          ? tokens.textPrimary
                          : tokens.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: DS.s24),
                  Icon(
                    widget.icon,
                    color: _isFocused
                        ? (widget.isWarning
                              ? tokens.error
                              : tokens.textPrimary)
                        : tokens.textSecondary,
                    size: 48,
                  ),
                  const SizedBox(height: DS.s24),
                  Text(
                    widget.label,
                    style: AppTextStyles.headline.copyWith(
                      color: tokens.textPrimary,
                      letterSpacing: 0.8,
                      fontWeight: AppTextStyles.titleFontWeight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DS.s4),
                  Text(
                    widget.subLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: _isFocused
                          ? tokens.textPrimary
                          : tokens.textMuted,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
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

class _BlinkingDotTV extends StatefulWidget {
  const _BlinkingDotTV();

  @override
  State<_BlinkingDotTV> createState() => _BlinkingDotTVState();
}

class _BlinkingDotTVState extends State<_BlinkingDotTV>
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
    return FadeTransition(
      opacity: _ctrl,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tokens.success,
              boxShadow: [BoxShadow(color: tokens.success, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'SIGNAL ESTABLISHED',
            style: AppTextStyles.caption.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
