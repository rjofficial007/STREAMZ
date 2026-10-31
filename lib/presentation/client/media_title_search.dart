import 'package:streamz/domain/models/media_item.dart';

class MediaTitleSearchResult {
  const MediaTitleSearchResult({required this.items, required this.hasMore});

  final List<MediaItem> items;
  final bool hasMore;
}

/// Searches titles and reads one extra match to disclose when results are capped.
class MediaTitleSearch {
  MediaTitleSearch(List<MediaItem> items)
    : _entries = items
          .map((item) => (item: item, normalizedTitle: item.title.toLowerCase()))
          .toList(growable: false);

  final List<({MediaItem item, String normalizedTitle})> _entries;

  MediaTitleSearchResult search(String query, {int limit = 50}) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty || limit <= 0) {
      return const MediaTitleSearchResult(items: [], hasMore: false);
    }

    final matches = _entries
        .where((entry) => entry.normalizedTitle.contains(normalizedQuery))
        .take(limit + 1)
        .map((entry) => entry.item)
        .toList(growable: false);
    return MediaTitleSearchResult(
      items: matches.take(limit).toList(growable: false),
      hasMore: matches.length > limit,
    );
  }
}
