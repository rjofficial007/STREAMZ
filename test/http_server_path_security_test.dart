import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/data/network/http_server.dart';

void main() {
  test(
    'shared-folder checks follow symlinks and allow missing in-root paths',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'streamz_path_security_',
      );
      final shared = Directory('${root.path}/shared')..createSync();
      final outside = Directory('${root.path}/outside')..createSync();
      final secret = File('${outside.path}/secret.mp4')
        ..writeAsStringSync('secret');
      final sharedFolders = [shared.path];

      try {
        expect(
          await HttpServerService.isPathAllowed(
            '${shared.path}/not-yet-created.mp4',
            sharedFolders,
          ),
          isTrue,
        );

        try {
          await Link('${shared.path}/escape').create(outside.path);
        } on FileSystemException {
          return; // Symlink creation is unavailable on this host.
        }

        expect(
          await HttpServerService.isPathAllowed(
            '${shared.path}/escape/secret.mp4',
            sharedFolders,
          ),
          isFalse,
        );
        expect(
          await HttpServerService.isPathAllowed(secret.path, sharedFolders),
          isFalse,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
