import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';

class MobileContentRail extends StatelessWidget {

  const MobileContentRail({super.key, required this.title, required this.subTitle, required this.items, required this.vm, required this.textPad, this.showProgress = false});
  final String title;
  final String subTitle;
  final List<MediaItem> items;
  final bool showProgress;
  final double textPad;
  final ClientViewModel vm;

  void _play(BuildContext context, MediaItem item) {
    final tokens = context.tokens;
    final vm = context.read<ClientViewModel>();

    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(AppIcons.play, color: tokens.textPrimary),
            title: Text(AppStrings.playNow, style: AppTextStyles.labelMd),
            onTap: () {
              context.pop();
              final idx = items.indexOf(item);
              context.push('/player', extra: {'items': items, 'startIndex': idx >= 0 ? idx : 0});
            },
          ),
          ListTile(
            leading: Icon(AppIcons.listPlus, color: tokens.textPrimary),
            title: Text(AppStrings.addToSharedQueue, style: AppTextStyles.labelMd),
            onTap: () {
              context.pop();
              vm.sendQueueCommand('add', item.toJson());
            },
          ),
          ListTile(
            leading: Icon(AppIcons.download, color: tokens.textPrimary),
            title: Text(AppStrings.downloadSignal, style: AppTextStyles.labelMd),
            onTap: () {
              context.pop();
              vm.downloadMedia(item: item, isPathBased: false);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(textPad, 0, textPad, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTextStyles.barlowBold(24, spacing: 2, color: tokens.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subTitle.toUpperCase(),
                style: AppTextStyles.mono(9, spacing: 2, color: tokens.textMuted),
              ),
            ],
          ),
        ),
        Container(
          height: 140,
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            color: tokens.surface1,
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            itemBuilder: (_, i) => _MobileRailCard(
              item: items[i],
              size: 140,
              showProgress: showProgress,
              vm: vm,
              onTap: () => _play(context, items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileRailCard extends StatefulWidget {

  const _MobileRailCard({required this.item, required this.size, required this.showProgress, required this.vm, required this.onTap});
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
      child: Container(
        width: widget.size,
        decoration: BoxDecoration(
          color: _isPressed ? tokens.textPrimary : tokens.surface2,
          border: Border(right: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 78,
              child: Container(
                color: tokens.background,
                child: NetworkImageFade(
                  url: widget.vm.thumbnailUrl(widget.item.id),
                  fit: BoxFit.cover,
                  fallbackIcon: widget.item.isAudio
                      ? AppIcons.music
                      : (widget.item.isImage ? AppIcons.image : AppIcons.video),
                ),
              ),
            ),
            if (widget.showProgress && widget.item.isInProgress)
              Container(
                height: 2,
                alignment: Alignment.centerLeft,
                color: tokens.border.withValues(alpha: 0.15),
                child: FractionallySizedBox(
                  widthFactor: widget.item.watchProgress,
                  child: Container(color: _isPressed ? tokens.background : tokens.accent),
                ),
              ),
            Expanded(
              flex: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                ),
                child: Text(
                  widget.item.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.mono(
                    10,
                    spacing: 1,
                    color: _isPressed ? tokens.background : tokens.textSecondary,
                    weight: _isPressed ? FontWeight.bold : FontWeight.normal,
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
