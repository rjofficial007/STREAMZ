import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';

/// TVStationRail displays active network broadcasts.
/// Features a "LIVE" indicator and station-specific metadata.
class TVStationRail extends StatelessWidget {

  const TVStationRail({
    super.key,
    required this.stations,
    required this.railIndex,
    required this.focusedRail,
    required this.onRailFocus,
    required this.vm,
  });
  final List<BroadcastStation> stations;
  final int railIndex;
  final int focusedRail;
  final Function(int) onRailFocus;
  final ClientViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final sidePadding = (size.width * 0.03).clamp(16.0, 48.0);
    final cardW = (size.width * 0.15).clamp(200.0, 380.0);
    final cardH = cardW;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rail Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.networkBroadcasts,
                style: AppTextStyles.barlowBold((size.width * 0.015).clamp(18.0, 28.0), spacing: 2, color: tokens.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.pathLive,
                style: AppTextStyles.mono(8, spacing: 2, color: tokens.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Horizontal List
        SizedBox(
          height: cardH + 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: sidePadding),
            itemCount: stations.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(right: 24),
              child: _TVStationCard(
                station: stations[i],
                width: cardW,
                height: cardH,
                isFocused: focusedRail == railIndex,
                vm: vm,
                onFocus: () => onRailFocus(railIndex),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TVStationCard extends StatefulWidget {

  const _TVStationCard({
    required this.station, 
    required this.width, 
    required this.height, 
    required this.isFocused, 
    required this.vm, 
    required this.onFocus
  });
  final BroadcastStation station;
  final double width;
  final double height;
  final bool isFocused;
  final ClientViewModel vm;
  final VoidCallback onFocus;

  @override
  State<_TVStationCard> createState() => _TVStationCardState();
}

class _TVStationCardState extends State<_TVStationCard> {
  bool _focused = false;

  Future<void> _tuneIn() async {
    final res = await widget.vm.joinStation(widget.station.id);
    if (res != null && mounted) {
      await context.push('/tv-player', extra: {
        'items': res.playlist,
        'startIndex': res.itemIndex,
        'isPathBased': false,
        'startOffset': res.position,
        'autoPlay': !res.isPaused,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final nowPlaying = widget.station.nowPlaying;
    final title = widget.station.name.toUpperCase();
    final itemTitle = nowPlaying != null 
        ? nowPlaying.item.title.toUpperCase() 
        : AppStrings.awaitingSignal;

    return Focus(
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) {
          widget.onFocus();
          handleTVFocusScroll(v, context);
        }
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, _tuneIn),
      child: GestureDetector(
        onTap: _tuneIn,
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: _focused ? tokens.textPrimary : tokens.surface2,
              border: Border.all(
                color: _focused ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15), 
                width: _focused ? 4 : 1
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.barlowBold(20, spacing: 1, color: _focused ? tokens.background : tokens.textPrimary),
                        maxLines: 1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: _focused ? tokens.background : tokens.textPrimary)
                      ),
                      child: Text(
                        AppStrings.live,
                        style: AppTextStyles.mono(10, weight: FontWeight.bold, color: _focused ? tokens.background : tokens.textPrimary),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.statusNowPlaying, 
                      style: AppTextStyles.mono(10, spacing: 1, color: _focused ? tokens.background.withValues(alpha: 0.5) : tokens.textMuted)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      itemTitle,
                      style: AppTextStyles.mono(12, color: _focused ? tokens.background : tokens.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
