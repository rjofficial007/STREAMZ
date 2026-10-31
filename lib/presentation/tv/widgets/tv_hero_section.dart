import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';

/// TVHeroSection displays featured content with a high-contrast layout.
/// It features large typography and a "Signal Strength" decorative bar.
class TVHeroSection extends StatefulWidget {
  const TVHeroSection({
    super.key,
    required this.items,
    required this.vm,
    required this.allItems,
  });
  final List<MediaItem> items;
  final ClientViewModel vm;
  final List<MediaItem> allItems;

  @override
  State<TVHeroSection> createState() => _TVHeroSectionState();
}

class _TVHeroSectionState extends State<TVHeroSection> {
  final int _index = 0; // Keeping as field for future multi-hero sliding logic
  final FocusNode _focusNode = FocusNode(debugLabel: 'TV featured media');
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final item = widget.items[_index];
    final fullIdx = widget.allItems.indexWhere(
      (candidate) => candidate.id == item.id,
    );
    await context.push<void>(
      '/tv-player',
      extra: {
        'items': widget.allItems,
        'startIndex': fullIdx != -1 ? fullIdx : 0,
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
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final item = widget.items[_index];
    final sidePadding = DS.hPad(size.width);

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, _play),
      child: GestureDetector(
        onTap: _play,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface1,
            borderRadius: BorderRadius.circular(DS.radius(24)),
            border: Border.all(
              color: _focused
                  ? tokens.focusColor
                  : tokens.border.withValues(alpha: 0.55),
              width: _focused ? 3 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DS.radius(23)),
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
                        'Featured',
                        style: AppTextStyles.text(
                          14,
                          weight: FontWeight.w500,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: AppTextStyles.display(
                          (size.width * 0.04).clamp(32.0, 64.0),
                          spacing: -1,
                          color: tokens.textPrimary,
                        ).copyWith(height: 0.9),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _HeroBtn(
                            label: 'Play now',
                            icon: AppIcons.play,
                            isFocused: _focused,
                            onTap: _play,
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    required this.onTap,
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
        color: isFocused ? tokens.textPrimary : tokens.surface3,
        borderRadius: BorderRadius.circular(DS.radius(14)),
        border: Border.all(
          color: isFocused ? tokens.textPrimary : tokens.borderStrong,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isFocused ? tokens.background : tokens.textPrimary,
            size: 14,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.text(
              14,
              weight: FontWeight.w500,
              color: isFocused ? tokens.background : tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
