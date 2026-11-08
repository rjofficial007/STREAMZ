import 'package:streamz/domain/models/media_item.dart';

enum MediaSearchFilter {
  all('All'),
  videos('Videos'),
  audio('Audio'),
  photos('Photos');

  const MediaSearchFilter(this.label);
  final String label;

  bool includes(MediaItem item) => switch (this) {
    all => true,
    videos => item.isVideo,
    audio => item.isAudio,
    photos => item.isImage,
  };
}

enum MediaSearchSort {
  name('Name'),
  recentlyPlayed('Recently played');

  const MediaSearchSort(this.label);
  final String label;
}

class MediaTitleSearchResult {
  const MediaTitleSearchResult({required this.items, required this.hasMore});

  final List<MediaItem> items;
  final bool hasMore;
}

/// Searches titles and reads one extra match to disclose when results are capped.
class MediaTitleSearch {
  MediaTitleSearch(List<MediaItem> items)
    : _nameEntries = items
          .map(
            (item) => (
              item: item,
              normalizedTitle: item.title.toLowerCase(),
            ),
          )
          .toList() {
    _nameEntries.sort(
      (a, b) => a.normalizedTitle.compareTo(b.normalizedTitle),
    );
    _recentEntries = [..._nameEntries]
      ..sort((a, b) {
        final recent = b.item.lastPlayedTimestamp.compareTo(
          a.item.lastPlayedTimestamp,
        );
        return recent != 0
            ? recent
            : a.normalizedTitle.compareTo(b.normalizedTitle);
      });
  }

  final List<({MediaItem item, String normalizedTitle})> _nameEntries;
  late final List<({MediaItem item, String normalizedTitle})> _recentEntries;

  MediaTitleSearchResult search(
    String query, {
    int limit = 50,
    MediaSearchFilter filter = MediaSearchFilter.all,
    MediaSearchSort sort = MediaSearchSort.name,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty || limit <= 0) {
      return const MediaTitleSearchResult(items: [], hasMore: false);
    }

    final entries = sort == MediaSearchSort.recentlyPlayed
        ? _recentEntries
        : _nameEntries;
    final matches = <MediaItem>[];
    for (final entry in entries) {
      if (entry.normalizedTitle.contains(normalizedQuery) &&
          filter.includes(entry.item)) {
        matches.add(entry.item);
        if (matches.length > limit) break;
      }
    }

    return MediaTitleSearchResult(
      items: matches.take(limit).toList(growable: false),
      hasMore: matches.length > limit,
    );
  }
}
