import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';

class MediaFavoriteButton extends StatelessWidget {
  const MediaFavoriteButton({
    super.key,
    required this.item,
    required this.viewModel,
    this.tvFocus = false,
  });

  final MediaItem item;
  final ClientViewModel viewModel;
  final bool tvFocus;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isFavorite = context.select<ClientViewModel, bool>(
      (viewModel) => viewModel.isFavorite(item.id),
    );
    final button = Material(
      color: Colors.black.withValues(alpha: 0.68),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: isFavorite
            ? AppStrings.removeFromFavorites
            : AppStrings.addToFavorites,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: Icon(
          AppIcons.favorite,
          size: 20,
          fill: isFavorite ? 1.0 : 0.0,
          color: isFavorite ? tokens.accent : tokens.textPrimary,
        ),
        onPressed: () => viewModel.toggleFavorite(item),
      ),
    );

    if (!tvFocus) return button;
    return Focus(
      onKeyEvent: (_, event) => handleTVSelectKey(
        event,
        () => viewModel.toggleFavorite(item),
      ),
      child: button,
    );
  }
}
