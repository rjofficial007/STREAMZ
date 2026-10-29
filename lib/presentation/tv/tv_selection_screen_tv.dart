// presentation/tv/tv_selection_screen_tv.dart
// ============================================================================
// STREAMZ — TV Interface Selection Gateway (NOC Dashboard)
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
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);

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
                          children: [
                            Expanded(
                              child: _TVModeCard(
                                label: 'MODERN UI',
                                subLabel: 'LARGE SCREEN DASHBOARD',
                                code: 'TV-01',
                                icon: LucideIcons.tv,
                                onTap: () =>
                                    context.push('/client/tv/home'),
                                autofocus: true,
                              ),
                            ),
                            const SizedBox(width: DS.s24),
                            Expanded(
                              child: _TVModeCard(
                                label: 'FILE SYSTEM',
                                subLabel: 'RAW ASSET NAVIGATION',
                                code: 'TV-02',
                                icon: LucideIcons.folderOpen,
                                onTap: () =>
                                    context.push('/client/tv/files'),
                              ),
                            ),
                            const SizedBox(width: DS.s24),
                            Expanded(
                              child: _TVModeCard(
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
                                  childAspectRatio: size.width > 1200
                                      ? 4
                                      : 5,
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
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ClientViewModel vm) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);
    final verticalPad = (size.height * 0.04).clamp(16.0, 40.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TV INTERFACE // SESSION ANALYSIS',
                  style: AppTextStyles.style(
                    color: tokens.textPrimary,
                    fontSize: (size.width * 0.02).clamp(20.0, 32.0),
                    fontWeight: AppTextStyles.titleFontWeight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: DS.s8),
                Container(
                  height: 2,
                  width: (size.width * 0.1).clamp(100.0, 200.0),
                  color: tokens.accent,
                ),
              ],
            ),
          ),
          const _StatusModule(label: 'ACTIVE MODE', value: 'TV MODE'),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          _StatusModule(label: 'HOST IP', value: vm.targetIp.toUpperCase()),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
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
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);
    final verticalPad = (size.height * 0.04).clamp(16.0, 40.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      child: Row(
        children: [
          Text(
            'SIGNAL ANALYSIS: OPTIMAL // LATENCY: LOW // ENCRYPTION: NONE',
            style: AppTextStyles.style(
              color: tokens.textMuted,
              fontSize: (size.width * 0.008).clamp(9.0, 12.0),
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

class _TVModeCard extends StatefulWidget {
  const _TVModeCard({
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
  State<_TVModeCard> createState() => _TVModeCardState();
}

class _TVModeCardState extends State<_TVModeCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused ? tokens.surface3 : tokens.surface1;
    final borderColor = _isFocused
        ? (widget.isWarning ? tokens.error : tokens.accent)
        : tokens.border;
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
            height: (size.height * 0.3).clamp(180.0, 300.0),
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
                    style: AppTextStyles.style(
                      color: _isFocused
                          ? tokens.textPrimary
                          : tokens.textMuted,
                      fontSize: (size.width * 0.008).clamp(9.0, 12.0),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: (size.height * 0.02).clamp(12.0, 24.0)),
                  Icon(
                    widget.icon,
                    color: _isFocused
                        ? (widget.isWarning
                              ? tokens.error
                              : tokens.textPrimary)
                        : tokens.textSecondary,
                    size: (size.width * 0.035).clamp(32.0, 56.0),
                  ),
                  SizedBox(height: (size.height * 0.02).clamp(12.0, 24.0)),
                  Text(
                    widget.label,
                    style: AppTextStyles.style(
                      color: tokens.textPrimary,
                      fontSize: (size.width * 0.018).clamp(20.0, 32.0),
                      letterSpacing: 0.8,
                      fontWeight: AppTextStyles.titleFontWeight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DS.s4),
                  Text(
                    widget.subLabel,
                    style: AppTextStyles.style(
                      color: _isFocused
                          ? tokens.textPrimary
                          : tokens.textMuted,
                      fontSize: (size.width * 0.008).clamp(9.0, 12.0),
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
