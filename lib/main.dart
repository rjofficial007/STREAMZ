// main.dart
// ============================================================================
// STREAMZ — Application Entry Point
// ============================================================================

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'domain/services/download_service.dart';
import 'domain/services/remote_command_service.dart';
import 'presentation/home/role_selection_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: Colors.transparent));

  // Boot DI container
  await setupServiceLocator();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DownloadService>(create: (_) => sl<DownloadService>()),
        ChangeNotifierProvider<RemoteCommandService>(create: (_) => sl<RemoteCommandService>()),
      ],
      child: const StreamzApp(),
    ),
  );
  // runApp(
  //   DevicePreview(
  //     enabled: !kReleaseMode,
  //     builder: (context) => MultiProvider(
  //       providers: [
  //         ChangeNotifierProvider<DownloadService>(create: (_) => sl<DownloadService>()),
  //         ChangeNotifierProvider<RemoteCommandService>(create: (_) => sl<RemoteCommandService>()),
  //       ],
  //       child: const StreamzApp(),
  //     ),
  //   ),
  // );
}

class StreamzApp extends StatelessWidget {
  const StreamzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STREAMZ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const RoleSelectionScreen(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.trackpad}),
      shortcuts: <ShortcutActivator, Intent>{const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(), const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent()},
    );
  }
}
