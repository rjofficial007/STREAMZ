// main.dart
// ============================================================================
// STREAMZ — Application Entry Point
// ============================================================================

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
import 'presentation/server/server_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: Colors.transparent));

  await setupServiceLocator();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DownloadService>(create: (_) => sl<DownloadService>()),
        ChangeNotifierProvider<RemoteCommandService>(create: (_) => sl<RemoteCommandService>()),
        ChangeNotifierProvider<ServerViewModel>(create: (_) => ServerViewModel()),
      ],
      child: const StreamzApp(),
    ),
  );
}

// FIX: Must be StatefulWidget so we can register WidgetsBindingObserver.
// This is the only correct way to get AppLifecycleState callbacks at app root.
class StreamzApp extends StatefulWidget {
  const StreamzApp({super.key});

  @override
  State<StreamzApp> createState() => _StreamzAppState();
}

class _StreamzAppState extends State<StreamzApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Called by the OS when app moves between foreground/background.
  // We forward this into the ServerViewModel via a global event bus
  // so the server can acquire WakeLock and background execution.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Notify the singleton server to handle lifecycle transitions.
    // ServerViewModel reads this via sl<> so it receives the event even
    // if the ServerDashboard widget is not in the tree.
    sl<AppLifecycleBroadcaster>().notify(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STREAMZ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const RoleSelectionScreen(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.trackpad}),
      // [CRITICAL TV FIX]: Spread WidgetsApp.defaultShortcuts FIRST.
      // Omitting this deletes the native D-Pad Up/Down/Left/Right bindings.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
        // Amazon Fire TV & certain Android TV "OK" buttons
        const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
      },
    );
  }
}

/// Lightweight broadcast bus so the root WidgetsBindingObserver can
/// forward AppLifecycleState to the ServerViewModel singleton without
/// requiring a BuildContext or widget tree traversal.
class AppLifecycleBroadcaster {
  final List<void Function(AppLifecycleState)> _listeners = [];

  void addListener(void Function(AppLifecycleState) cb) => _listeners.add(cb);

  void removeListener(void Function(AppLifecycleState) cb) => _listeners.remove(cb);

  void notify(AppLifecycleState state) {
    for (final cb in List.of(_listeners)) {
      cb(state);
    }
  }
}
