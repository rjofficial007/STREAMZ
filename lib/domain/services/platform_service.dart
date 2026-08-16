import 'dart:io';
import 'package:flutter/foundation.dart';

/// PlatformService centralizes OS-specific logic such as default media paths.
/// This improves testability and keeps ViewModels clean of 'if (Platform.is...)' checks.
class PlatformService {
  /// Returns a list of default "mounted" folders based on the current OS.
  List<String> getDefaultSharedFolders() {
    if (kIsWeb) return [];

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null) {
        // Standard Windows media libraries.
        return [
          '$home\\Videos', 
          '$home\\Music', 
          '$home\\Pictures',
          '$home\\Downloads'
        ];
      }
      return [r'C:\'];
    } 
    
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      // Android shared storage root. iOS is sandboxed but photo_manager handles it.
      return ['/storage/emulated/0'];
    } 
    
    if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux) {
       final home = Platform.environment['HOME'];
       if (home != null) {
         return ['$home/Videos', '$home/Music', '$home/Pictures'];
       }
    }

    return ['/'];
  }

  /// Returns true if the current platform requires explicit runtime permission
  /// screens (Android/iOS) vs auto-granting (Desktop/Web).
  bool requiresPermissionScreen() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android || 
           defaultTargetPlatform == TargetPlatform.iOS;
  }
}
