// presentation/client/interface_selection_screen_tv.dart
// ============================================================================
// STREAMZ — TV Interface Gateway (NOC Dashboard)
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
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);
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
                                    label: 'TV USER',
                                    subLabel: 'LARGE SCREEN OPTIMIZED',
                                    code: 'UI-01',
                                    icon: LucideIcons.tv,
                                    onTap: () => context.push('/client/tv'),
                                    autofocus: true,
                                  ),
                                ),
                                const SizedBox(width: DS.s24),
                                Expanded(
                                  child: _TVGatewayCard(
                                    label: 'MOBILE USER',
                                    subLabel: 'TOUCH INTERFACE EMULATION',
                                    code: 'UI-02',
                                    icon: LucideIcons.smartphone,
                                    onTap: () => context.push('/client/mobile'),
                                  ),
                                ),
                                const SizedBox(width: DS.s24),
                                Expanded(
                                  child: _TVGatewayCard(
                                    label: 'TERMINATE',
                                    subLabel: 'CLOSE CONNECTION',
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
                              'LIVE SIGNALS // DETECTED BROADCASTS',
                              style: AppTextStyles.style(
                                color: tokens.textMuted,
                                fontSize: (size.width * 0.008).clamp(9.0, 12.0),
                                letterSpacing: 0.5,
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
                _buildFooter(context),
              ],
            ),
          ),
        ],
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
                  'GATEWAY MODE // SYSTEM ANALYSIS',
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
          _StatusModule(
            label: 'LINK STATUS',
            value: vm.isConnected ? 'ESTABLISHED' : 'SEVERED',
          ),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          _StatusModule(label: 'UPSTREAM', value: vm.targetIp.toUpperCase()),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          _StatusModule(
            label: 'STATIONS',
            value: '${vm.stations.length} ACTIVE',
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

  Widget _buildEmptySignals(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(DS.s48),
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Center(
        child: Column(
      children: [
        Icon(LucideIcons.radioTower, size: 48, color: tokens.textMuted),
        const SizedBox(height: DS.s16),
        Text(
          'NO LIVE BROADCASTS DETECTED',
          style: AppTextStyles.body.copyWith(
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

class _TVGatewayCard extends StatefulWidget {
  const _TVGatewayCard({
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
  State<_TVGatewayCard> createState() => _TVGatewayCardState();
}

class _TVGatewayCardState extends State<_TVGatewayCard> {
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
