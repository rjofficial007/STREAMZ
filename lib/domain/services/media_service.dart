import 'package:flutter/foundation.dart';
import 'package:streamz/data/repositories/media_repository.dart';
import 'package:streamz/domain/models/media_item.dart';

class MediaService extends ChangeNotifier {

  MediaService({required MediaRepository repo}) : _repo = repo;
  final MediaRepository _repo;

  List<MediaItem> _allMedia = [];
  List<MediaItem> _filteredMedia = [];
  String _searchQuery = '';

  List<MediaItem> get allMedia => _allMedia;
  List<MediaItem> get filteredMedia => _filteredMedia;

  void loadMedia({bool shareVideos = true, bool shareMusic = true, bool shareImages = true}) {
    _allMedia = _repo.getLocalMediaItems(
      shareVideos: shareVideos,
      shareMusic: shareMusic,
      shareImages: shareImages,
    );
    _applyFilter();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilter();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredMedia = List.from(_allMedia);
    } else {
      _filteredMedia = _allMedia.where((item) => item.title.toLowerCase().contains(_searchQuery) ||
               (item.artist?.toLowerCase().contains(_searchQuery) ?? false) ||
               (item.album?.toLowerCase().contains(_searchQuery) ?? false) ||
               item.folder.toLowerCase().contains(_searchQuery)).toList();
    }
    notifyListeners();
  }
}
