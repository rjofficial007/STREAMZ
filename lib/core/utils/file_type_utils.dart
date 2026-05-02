// core/utils/file_type_utils.dart

enum MediaFileType { video, audio, image, document, apk, archive, other }

abstract final class FileTypeUtils {
  static const _videoExts = {'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', '3gp', 'm4v', 'ts'};
  static const _audioExts = {'mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg', 'opus', 'wma'};
  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'avif'};
  static const _docExts = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'md'};
  static const _archExts = {'zip', 'rar', '7z', 'tar', 'gz', 'bz2'};

  static MediaFileType fromExtension(String ext) {
    final lower = ext.toLowerCase().replaceAll('.', '');
    if (_videoExts.contains(lower)) return MediaFileType.video;
    if (_audioExts.contains(lower)) return MediaFileType.audio;
    if (_imageExts.contains(lower)) return MediaFileType.image;
    if (_docExts.contains(lower)) return MediaFileType.document;
    if (lower == 'apk') return MediaFileType.apk;
    if (_archExts.contains(lower)) return MediaFileType.archive;
    return MediaFileType.other;
  }

  static MediaFileType fromFilename(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last : '';
    return fromExtension(ext);
  }

  static String toMediaType(MediaFileType type) {
    switch (type) {
      case MediaFileType.video:
        return 'video';
      case MediaFileType.audio:
        return 'audio';
      case MediaFileType.image:
        return 'image';
      default:
        return 'other';
    }
  }

  static bool isPlayable(MediaFileType type) => type == MediaFileType.video || type == MediaFileType.audio || type == MediaFileType.image;

  static bool isVideo(String filename) => fromFilename(filename) == MediaFileType.video;
  static bool isAudio(String filename) => fromFilename(filename) == MediaFileType.audio;
  static bool isImage(String filename) => fromFilename(filename) == MediaFileType.image;

  static String contentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'mp4': 'video/mp4',
      'webm': 'video/webm',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'aac': 'audio/aac',
      'flac': 'audio/flac',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'm4a': 'audio/mp4',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}
