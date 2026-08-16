import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';

/// TVHeroSection displays featured content with a high-contrast layout.
/// It features large typography and a "Signal Strength" decorative bar.
class TVHeroSection extends StatefulWidget {

  const TVHeroSection({
    super.key, 
    required this.items, 
    required this.vm, 
    required this.allItems
  });
  final List<MediaItem> items;
  final ClientViewModel vm;
  final List<MediaItem> allItems;

  @override
  State<TVHeroSection> createState() => _TVHeroSectionState();
}

class _TVHeroSectionState extends State<TVHeroSection> {
  final int _index = 0; // Keeping as field for future multi-hero sliding logic
  bool _focused = false;

  void _play() {
    final item = widget.items[_index];
    final fullIdx = widget.allItems.indexOf(item);
    context.push('/tv-player', extra: {
      'items': widget.allItems,
      'startIndex': fullIdx != -1 ? fullIdx : 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final item = widget.items[_index];
    final sidePadding = (size.width * 0.03).clamp(16.0, 48.0);

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, _play),
      child: GestureDetector(
        onTap: _play,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface1,
            border: Border.all(
              color: _focused ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15), 
              width: _focused ? 4 : 1
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Hero Thumbnail with low opacity for background effect
              Opacity(
                opacity: 0.4,
                child: NetworkImageFade(
                  url: widget.vm.thumbnailUrl(item.id),
                  fit: BoxFit.cover,
                ),
              ),
              // Content Overlay
              Padding(
                padding: EdgeInsets.all(sidePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'FEATURED_SIGNAL // 0${_index + 1}',
                      style: AppTextStyles.mono(12, spacing: 4, weight: FontWeight.bold, color: tokens.accent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title.toUpperCase(),
                      style: AppTextStyles.barlowBlack((size.width * 0.04).clamp(32.0, 64.0), spacing: -1, color: tokens.textPrimary).copyWith(height: 0.9),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _HeroBtn(
                          label: 'INITIATE PLAYBACK', 
                          icon: AppIcons.play, 
                          isFocused: _focused, 
                          onTap: _play
                        ),
                        const SizedBox(width: 16),
                        _HeroBtn(
                          label: 'SIGNAL_INFO', 
                          icon: Icons.info_outline, 
                          isFocused: false, 
                          onTap: () {}
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Signal Strength Bar (Brutalist Decoration)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 4,
                child: Row(
                  children: List.generate(20, (i) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      color: i < 15 ? tokens.accent : tokens.surface3,
                    ),
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBtn extends StatelessWidget {

  const _HeroBtn({
    required this.label, 
    required this.icon, 
    required this.isFocused, 
    required this.onTap
  });
  final String label;
  final IconData icon;
  final bool isFocused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isFocused ? tokens.textPrimary : Colors.transparent,
        border: Border.all(color: tokens.textPrimary, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            color: isFocused ? tokens.background : tokens.textPrimary, 
            size: 14
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.mono(10, weight: FontWeight.bold, spacing: 2, color: isFocused ? tokens.background : tokens.textPrimary),
          ),
        ],
      ),
    );
  }
}
