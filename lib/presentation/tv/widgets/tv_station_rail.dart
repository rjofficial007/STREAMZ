import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/app_live_station_card.dart';

/// TV rail for active network broadcasts with standard D-pad focus styling.
class TVStationRail extends StatelessWidget {
  const TVStationRail({
    super.key,
    required this.stations,
    required this.railIndex,
    required this.onRailFocus,
    required this.vm,
  });

  final List<BroadcastStation> stations;
  final int railIndex;
  final ValueChanged<int> onRailFocus;
  final ClientViewModel vm;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sidePadding = DS.hPad(size.width);
    final cardWidth = (size.width * 0.15).clamp(200.0, 380.0);
    final cardHeight = (cardWidth * 0.68).clamp(164.0, 260.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.networkBroadcasts,
                style: AppTextStyles.heading(
                  (size.width * 0.016).clamp(20.0, 30.0),
                  spacing: -0.3,
                  color: context.tokens.textPrimary,
                ),
              ),
              const SizedBox(height: DS.s4),
              Text(
                AppStrings.pathLive,
                style: AppTextStyles.text(12, color: context.tokens.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: DS.s16),
        SizedBox(
          height: cardHeight + DS.s24,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: sidePadding),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final station = stations[index];
              return Padding(
                padding: const EdgeInsets.only(right: DS.s16),
                child: _TVStationRailCard(
                  key: ValueKey(station.id),
                  station: station,
                  vm: vm,
                  width: cardWidth,
                  height: cardHeight,
                  onFocus: () => onRailFocus(railIndex),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TVStationRailCard extends StatefulWidget {
  const _TVStationRailCard({
    super.key,
    required this.station,
    required this.vm,
    required this.width,
    required this.height,
    required this.onFocus,
  });

  final BroadcastStation station;
  final ClientViewModel vm;
  final double width;
  final double height;
  final VoidCallback onFocus;

  @override
  State<_TVStationRailCard> createState() => _TVStationRailCardState();
}

class _TVStationRailCardState extends State<_TVStationRailCard> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'TV live station');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _tuneIn() async {
    final result = await widget.vm.joinStation(widget.station.id);
    if (result == null || !mounted) return;
    await context.push<void>(
      '/tv-player',
      extra: {
        'items': result.playlist,
        'startIndex': result.itemIndex,
        'isPathBased': false,
        'startOffset': result.position,
        'autoPlay': !result.isPaused,
      },
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      handleTVFocusScroll(true, context);
    });
  }

  @override
  Widget build(BuildContext context) => AppLiveStationCard(
    width: widget.width,
    height: widget.height,
    title: widget.station.name,
    trackTitle:
        widget.station.nowPlaying?.item.title ?? AppStrings.awaitingSignal,
    liveLabel: AppStrings.live,
    nowPlayingLabel: AppStrings.statusNowPlaying,
    focusNode: _focusNode,
    onFocusChanged: (focused) {
      if (focused) widget.onFocus();
    },
    onTap: () => unawaited(_tuneIn()),
  );
}
