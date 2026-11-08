import 'dart:async';

import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/media_actions_sheet.dart';
import 'package:streamz/presentation/shared/media_details_text.dart';

class MobileContentRail extends StatelessWidget {
  const MobileContentRail({
    super.key,
    required this.title,
    required this.items,
    required this.vm,
    required this.textPad,
    this.showProgress = false,
  });
  final String title;
  final List<MediaItem> items;
  final bool showProgress;
  final double textPad;
  final ClientViewModel vm;

  void _play(BuildContext context, MediaItem item) {
    unawaited(
      showMediaActionsSheet(
        context: context,
        item: item,
        playlist: items,
        viewModel: vm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textScaler = MediaQuery.textScalerOf(context);
    final metadataHeight =
        15.0 + textScaler.scale(12) * 1.4 + textScaler.scale(11) * 1.2;
    final cardHeight =
        148.0 +
        (metadataHeight > 76 ? metadataHeight : 76.0) +
        (showProgress ? 3.0 : 0.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(textPad, 0, textPad, 12),
          child: Text(
            title,
            style: AppTextStyles.heading(
              22,
              spacing: -0.4,
              color: tokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: textPad),
            itemCount: items.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _MobileRailCard(
                item: items[i],
                size: 148,
                showProgress: showProgress,
                vm: vm,
                onTap: () => _play(context, items[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileRailCard extends StatefulWidget {
  const _MobileRailCard({
    required this.item,
    required this.size,
    required this.showProgress,
    required this.vm,
    required this.onTap,
  });
  final MediaItem item;
  final double size;
  final bool showProgress;
  final ClientViewModel vm;
  final VoidCallback onTap;

  @override
  State<_MobileRailCard> createState() => _MobileRailCardState();
}

class _MobileRailCardState extends State<_MobileRailCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DS.radius(16)),
        child: Container(
          width: widget.size,
          decoration: BoxDecoration(
            color: tokens.surface1,
            border: Border.all(color: tokens.border.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: Container(
                  color: tokens.background,
                  child: NetworkImageFade(
                    url: widget.vm.thumbnailUrl(widget.item.id),
                    fit: BoxFit.cover,
                    fallbackIcon: widget.item.isAudio
                        ? AppIcons.music
                        : (widget.item.isImage
                              ? AppIcons.image
                              : AppIcons.video),
                  ),
                ),
              ),
              if (widget.showProgress && widget.item.isInProgress)
                Container(
                  height: 3,
                  alignment: Alignment.centerLeft,
                  color: tokens.border.withValues(alpha: 0.15),
                  child: FractionallySizedBox(
                    widthFactor: widget.item.watchProgress,
                    child: Container(
                      color: _isPressed ? tokens.background : tokens.accent,
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
                  decoration: BoxDecoration(color: tokens.surface1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.text(
                          12,
                          color: tokens.textSecondary,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      MediaDetailsText(item: widget.item),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
