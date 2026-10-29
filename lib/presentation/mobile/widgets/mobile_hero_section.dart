import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/core/theme/design_tokens.dart';

class MobileHeroSection extends StatefulWidget {
  const MobileHeroSection({
    super.key,
    required this.items,
    required this.vm,
    required this.allItems,
  });
  final List<MediaItem> items;
  final ClientViewModel vm;
  final List<MediaItem> allItems;

  @override
  State<MobileHeroSection> createState() => _MobileHeroSectionState();
}

class _MobileHeroSectionState extends State<MobileHeroSection> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (_pageCtrl.hasClients) {
          var next = _currentPage + 1;
          if (next >= widget.items.length) next = 0;
          _pageCtrl.animateToPage(
            next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _play(BuildContext context, MediaItem item) {
    final idx = widget.allItems.indexOf(item);
    context.push(
      '/player',
      extra: {'items': widget.allItems, 'startIndex': idx >= 0 ? idx : 0},
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DS.radius(22)),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return GestureDetector(
                  onTap: () => _play(context, item),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: tokens.surface1),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: tokens.surface2,
                            child: NetworkImageFade(
                              url: widget.vm.thumbnailUrl(item.id),
                              fit: BoxFit.cover,
                              fallbackIcon: item.isAudio
                                  ? AppIcons.music
                                  : (item.isImage
                                        ? AppIcons.image
                                        : AppIcons.video),
                            ),
                          ),
                        ),
                        Container(
                          height: 72,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: tokens.surface1.withValues(alpha: 0.96),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.textPrimary,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  AppStrings.play,
                                  style: AppTextStyles.text(
                                    12,
                                    weight: FontWeight.w600,
                                    color: tokens.background,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.statusHighlighted,
                                      style: AppTextStyles.text(
                                        11,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.heading(
                                        18,
                                        spacing: -0.2,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (widget.items.length > 1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Row(
                  children: List.generate(
                    widget.items.length,
                    (index) => Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(right: 1),
                        color: _currentPage == index
                            ? tokens.accent
                            : tokens.background.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
