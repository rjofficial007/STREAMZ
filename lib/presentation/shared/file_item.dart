// presentation/shared/file_item.dart
// Shared file-item model used by both mobile and TV file managers.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:streamz/core/utils/file_type_utils.dart';

enum SFileType { folder, image, video, audio, document, apk, archive, other }

class SFileItem {

  const SFileItem({required this.name, required this.path, required this.isDirectory, required this.size, required this.type, this.isPathBased = true, this.itemCount = 0});

  factory SFileItem.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final isDir = json['isDirectory'] == true;
    final path = json['path']?.toString() ?? '';
    final size = (json['size'] as num?)?.toInt() ?? 0;
    final count = (json['itemCount'] as num?)?.toInt() ?? 0;

    var type = SFileType.other;
    if (isDir) {
      type = SFileType.folder;
    } else {
      final ft = FileTypeUtils.fromFilename(name);
      switch (ft) {
        case MediaFileType.video:
          type = SFileType.video;
          break;
        case MediaFileType.audio:
          type = SFileType.audio;
          break;
        case MediaFileType.image:
          type = SFileType.image;
          break;
        case MediaFileType.document:
          type = SFileType.document;
          break;
        case MediaFileType.apk:
          type = SFileType.apk;
          break;
        case MediaFileType.archive:
          type = SFileType.archive;
          break;
        default:
          type = SFileType.other;
      }
    }

    return SFileItem(name: name, path: path, isDirectory: isDir, size: size, type: type, isPathBased: true, itemCount: count);
  }
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final SFileType type;
  final bool isPathBased;
  final int itemCount;

  String get ext => name.contains('.') ? name.split('.').last.toLowerCase() : '';

  bool get isPlayable => type == SFileType.video || type == SFileType.audio || type == SFileType.image;

  String get mediaType {
    switch (type) {
      case SFileType.video:
        return 'video';
      case SFileType.audio:
        return 'audio';
      case SFileType.image:
        return 'image';
      default:
        return 'other';
    }
  }

  String get sizeLabel {
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get cardMetadata => isDirectory
      ? '$itemCount items'
      : [
          if (sizeLabel.isNotEmpty) sizeLabel,
          typeLabel,
        ].join(' · ');

  IconData get icon {
    switch (type) {
      case SFileType.folder:
        return LucideIcons.folder;
      case SFileType.image:
        return LucideIcons.image;
      case SFileType.video:
        return LucideIcons.video;
      case SFileType.audio:
        return LucideIcons.music;
      case SFileType.document:
        return LucideIcons.fileText;
      case SFileType.apk:
        return LucideIcons.bot;
      case SFileType.archive:
        return LucideIcons.archive;
      default:
        return LucideIcons.file;
    }
  }

  String get typeLabel {
    switch (type) {
      case SFileType.folder:
        return 'Folder';
      case SFileType.image:
        return 'Image';
      case SFileType.video:
        return 'Video';
      case SFileType.audio:
        return 'Audio';
      case SFileType.document:
        return 'Document';
      case SFileType.apk:
        return 'APK';
      case SFileType.archive:
        return 'Archive';
      default:
        return ext.isNotEmpty ? ext.toUpperCase() : 'File';
    }
  }
}
