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
    final sidePadding = (size.width * 0.03).clamp(16.0, 48.0);
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
                child: AppLiveStationCard(
                  width: cardWidth,
                  height: cardHeight,
                  title: station.name,
                  trackTitle: station.nowPlaying?.item.title ??
                      AppStrings.awaitingSignal,
                  liveLabel: AppStrings.live,
                  nowPlayingLabel: AppStrings.statusNowPlaying,
                  onFocusChanged: (focused) {
                    if (focused) onRailFocus(railIndex);
                  },
                  onTap: () => unawaited(_tuneIn(context, station)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _tuneIn(BuildContext context, BroadcastStation station) async {
    final result = await vm.joinStation(station.id);
    if (result == null || !context.mounted) return;
    await context.push(
      '/tv-player',
      extra: {
        'items': result.playlist,
        'startIndex': result.itemIndex,
        'isPathBased': false,
        'startOffset': result.position,
        'autoPlay': !result.isPaused,
      },
    );
  }
}
