import 'package:flutter/foundation.dart';
import '../models/media_item.dart';

class QueueItem {
  final MediaItem media;
  final String addedBy;
  int votes;
  final DateTime addedAt;

  QueueItem({required this.media, required this.addedBy, this.votes = 0, DateTime? addedAt}) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'media': media.toJson(),
    'addedBy': addedBy,
    'votes': votes,
    'addedAt': addedAt.toIso8601String(),
  };

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
    media: MediaItem.fromJson(json['media']),
    addedBy: json['addedBy'] ?? 'Unknown',
    votes: json['votes'] ?? 0,
    addedAt: json['addedAt'] != null ? DateTime.parse(json['addedAt']) : null,
  );
}

class QueueService extends ChangeNotifier {
  final List<QueueItem> _queue = [];
  bool _isLocked = false;
  
  List<QueueItem> get queue => List.unmodifiable(_queue);
  bool get isLocked => _isLocked;

  void setLocked(bool locked) {
    _isLocked = locked;
    notifyListeners();
  }

  void addItem(MediaItem item, String userId) {
    if (_isLocked && userId != 'SERVER') return;
    _queue.add(QueueItem(media: item, addedBy: userId));
    _sort();
    notifyListeners();
  }

  void voteItem(String mediaId, int delta) {
    final idx = _queue.indexWhere((i) => i.media.id == mediaId);
    if (idx != -1) {
      _queue[idx].votes += delta;
      _sort();
      notifyListeners();
    }
  }

  void removeTop() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0);
      notifyListeners();
    }
  }

  void _sort() {
    // Trending logic: Priority to votes, then by newest added
    _queue.sort((a, b) {
      final voteComp = b.votes.compareTo(a.votes);
      if (voteComp != 0) return voteComp;
      return b.addedAt.compareTo(a.addedAt);
    });
  }
  
  void updateFromRemote(dynamic data) {
    _queue.clear();
    if (data is Map) {
      final items = data['items'] as List?;
      if (items != null) {
        for (var item in items) {
          _queue.add(QueueItem.fromJson(item as Map<String, dynamic>));
        }
      }
      _isLocked = data['isLocked'] == true;
    } else if (data is List) {
      // Compatibility with older protocol
      for (var item in data) {
        _queue.add(QueueItem.fromJson(item as Map<String, dynamic>));
      }
    }
    notifyListeners();
  }
}
