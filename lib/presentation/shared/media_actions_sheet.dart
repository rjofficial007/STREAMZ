import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/core/utils/format_utils.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/app_bottom_sheet.dart';

Future<void> showMediaActionsSheet({
  required BuildContext context,
  required MediaItem item,
  required List<MediaItem> playlist,
  required ClientViewModel viewModel,
  bool isPathBased = false,
  bool isTV = false,
}) async {
  final pageContext = context;
  final playerRoute = isTV ? '/tv-player' : '/player';
  await showAppBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(
            title: 'Media actions',
            subtitle: item.title,
            icon: item.isVideo
                ? LucideIcons.video
                : item.isAudio
                ? LucideIcons.music
                : LucideIcons.image,
          ),
          AppSheetOption(
            title: item.isInProgress
                ? 'Resume from ${formatDuration(item.lastPosition)}'
                : 'Play now',
            subtitle: item.isInProgress
                ? 'Continue where you left off'
                : 'Start playback now',
            icon: LucideIcons.play,
            onTap: () {
              Navigator.pop(sheetContext);
              final index = playlist.indexWhere(
                (media) => media.id == item.id,
              );
              pageContext.push(
                playerRoute,
                extra: {
                  'items': playlist,
                  'startIndex': index < 0 ? 0 : index,
                  'isPathBased': isPathBased,
                  if (item.isInProgress)
                    'startOffset': Duration(seconds: item.lastPosition),
                },
              );
            },
          ),
          if (item.isInProgress)
            AppSheetOption(
              title: 'Play from start',
              subtitle: 'Restart this item from the beginning',
              icon: LucideIcons.rotateCcw,
              onTap: () {
                Navigator.pop(sheetContext);
                final index = playlist.indexWhere(
                  (media) => media.id == item.id,
                );
                pageContext.push(
                  playerRoute,
                  extra: {
                    'items': playlist,
                    'startIndex': index < 0 ? 0 : index,
                    'isPathBased': isPathBased,
                    'startOffset': Duration.zero,
                  },
                );
              },
            ),
          AppSheetOption(
            title: viewModel.isFavorite(item.id)
                ? 'Remove from favorites'
                : 'Add to favorites',
            subtitle: viewModel.isFavorite(item.id)
                ? 'Remove this item from saved media'
                : 'Keep this item in your favorites',
            icon: LucideIcons.heart,
            onTap: () async {
              await viewModel.toggleFavorite(item);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
          ),
          AppSheetOption(
            title: 'Add to shared queue',
            subtitle: 'Let connected devices vote on what plays next',
            icon: LucideIcons.listPlus,
            onTap: () {
              Navigator.pop(sheetContext);
              viewModel.sendQueueCommand('add', item.toJson());
            },
          ),
          AppSheetOption(
            title: 'Download',
            subtitle: 'Save this item to this device',
            icon: LucideIcons.download,
            onTap: () {
              Navigator.pop(sheetContext);
              viewModel.downloadMedia(item: item, isPathBased: isPathBased);
            },
          ),
          SizedBox(
            height: MediaQuery.paddingOf(sheetContext).bottom + DS.s16,
          ),
        ],
      ),
    ),
  );
}
