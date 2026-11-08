import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/domain/models/media_item.dart';

void main() {
  group('MediaItem', () {
    test('should be case-insensitive for media types', () {
      const video = MediaItem(id: '1', title: 'Video', duration: 100, type: 'VIDEO', folder: 'root');
      const audio = MediaItem(id: '2', title: 'Audio', duration: 100, type: 'audio', folder: 'root');
      const image = MediaItem(id: '3', title: 'Image', duration: 0, type: 'Image', folder: 'root');

      expect(video.isVideo, isTrue);
      expect(audio.isAudio, isTrue);
      expect(image.isImage, isTrue);
    });

    test('fromJson tolerates non-string metadata values (C6)', () {
      final item = MediaItem.fromJson({
        'id': '4',
        'title': 'Weird',
        'duration': 5,
        'type': 'video',
        'folder': 'root',
        // A single non-string value used to throw and kill the parse of
        // the entire media list.
        'metadata': {'bitrate': 320000, 'year': 2026, 'flag': true, 'empty': null},
      });
      expect(item.metadata['bitrate'], '320000');
      expect(item.metadata['year'], '2026');
      expect(item.metadata['flag'], 'true');
      expect(item.metadata.containsKey('empty'), isFalse);
    });

    test('fromJson tolerates missing or non-map metadata (C6)', () {
      expect(MediaItem.fromJson({'id': '5', 'title': 'T'}).metadata, isEmpty);
      expect(
        MediaItem.fromJson({'id': '6', 'title': 'T', 'metadata': 'oops'}).metadata,
        isEmpty,
      );
    });
  });
}
