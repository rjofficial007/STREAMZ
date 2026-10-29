import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';

/// TVContentRail displays a horizontal list of media items.
/// Optimized for D-pad navigation with scale and focus effects.
class TVContentRail extends StatelessWidget {
  const TVContentRail({
    super.key,
    required this.title,
    required this.items,
    this.showProgress = false,
    required this.railIndex,
    required this.focusedRail,
    required this.onRailFocus,
    required this.vm,
  });
  final String title;
  final List<MediaItem> items;
  final bool showProgress;
  final int railIndex;
  final int focusedRail;
  final Function(int) onRailFocus;
  final ClientViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final sidePadding = (size.width * 0.03).clamp(16.0, 48.0);
    final cardW = (size.width * 0.22).clamp(DS.railCardWTV, 420.0);
    final cardH = cardW * 9 / 16;
    final audioCardSize = (cardW * 0.64).clamp(DS.railCardWTVSq, 250.0);
    final listHeight = (cardH > audioCardSize ? cardH : audioCardSize) + 56;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rail Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: Text(
            title,
            style: AppTextStyles.heading(
              (size.width * 0.014).clamp(18.0, 26.0),
              spacing: -0.3,
              color: tokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Horizontal List
        SizedBox(
          height: listHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: sidePadding),
            itemCount: items.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(right: 24),
              child: _TVContentCard(
                item: items[i],
                allItems: items,
                vm: vm,
                showProgress: showProgress,
                onFocus: () => onRailFocus(railIndex),
                cardW: items[i].isAudio ? audioCardSize : cardW,
                cardH: items[i].isAudio ? audioCardSize : cardH,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TVContentCard extends StatefulWidget {
  const _TVContentCard({
    required this.item,
    required this.allItems,
    required this.vm,
    this.showProgress = false,
    required this.onFocus,
    required this.cardW,
    required this.cardH,
  });
  final MediaItem item;
  final List<MediaItem> allItems;
  final ClientViewModel vm;
  final bool showProgress;
  final VoidCallback onFocus;
  final double cardW;
  final double cardH;

  @override
  State<_TVContentCard> createState() => _TVContentCardState();
}

class _TVContentCardState extends State<_TVContentCard> {
  bool _focused = false;

  void _play() {
    context.push(
      '/tv-player',
      extra: {
        'items': widget.allItems,
        'startIndex': widget.allItems.indexOf(widget.item),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);

    return Focus(
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) {
          widget.onFocus();
          handleTVFocusScroll(v, context);
        }
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, _play),
      child: GestureDetector(
        onTap: _play,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Visual with Scale effect on focus
            AnimatedScale(
              scale: _focused ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: widget.cardW,
                height: widget.cardH,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(DS.radius(16)),
                  border: Border.all(
                    color: _focused
                        ? tokens.textPrimary
                        : tokens.border.withValues(alpha: 0.55),
                    width: _focused ? 3 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DS.radius(15)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetworkImageFade(
                        url: widget.vm.thumbnailUrl(widget.item.id),
                        fit: BoxFit.cover,
                      ),
                      // Progress Indicator (if item is partially watched)
                      if (widget.showProgress && widget.item.watchProgress > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 3,
                          child: Container(
                            color: tokens.surface3,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: widget.item.watchProgress.clamp(
                                0.0,
                                1.0,
                              ),
                              child: Container(color: tokens.accent),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Card title
            SizedBox(
              width: widget.cardW,
              child: Text(
                widget.item.title,
                style: AppTextStyles.text(
                  (size.width * 0.008).clamp(16.0, 22.0),
                  color: _focused ? tokens.textPrimary : tokens.textSecondary,
                  weight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
