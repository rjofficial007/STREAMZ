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
  });
}
