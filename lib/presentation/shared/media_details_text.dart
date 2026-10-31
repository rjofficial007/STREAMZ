import 'package:flutter/material.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/utils/format_utils.dart';
import 'package:streamz/domain/models/media_item.dart';

/// Compact metadata for media cards. It only renders values provided by the
/// catalog and never probes files during scrolling.
class MediaDetailsText extends StatelessWidget {
  const MediaDetailsText({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final format = _format;
    final resolution = _resolution;
    final details = <String>[
      if (item.duration > 0) formatDuration(item.duration),
      if (format != null) format,
      if (resolution != null) resolution,
    ];
    if (details.isEmpty) return const SizedBox.shrink();

    return Text(
      details.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: tokens.textMuted,
        fontSize: 11,
        height: 1.2,
        letterSpacing: 0.2,
      ),
    );
  }

  String? get _format {
    final name = item.title.trim();
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) return null;

    final metadataFormat = item.metadata['format']?.trim();
    if (metadataFormat != null && metadataFormat.isNotEmpty) {
      return metadataFormat.replaceFirst(RegExp(r'^\.'), '').toUpperCase();
    }
    return null;
  }

  String? get _resolution {
    final explicit = item.metadata['resolution']?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final width = int.tryParse(item.metadata['width'] ?? '');
    final height = int.tryParse(item.metadata['height'] ?? '');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return '${width}×$height';
  }
}
