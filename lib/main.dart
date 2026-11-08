// main.dart
// ============================================================================
// STREAMZ — Application Entry Point
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/di/service_locator.dart';
import 'package:streamz/core/navigation/app_router.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/core/theme/theme_service.dart';
import 'package:streamz/core/util/lifecycle_broadcaster.dart';
import 'package:streamz/domain/services/download_service.dart';
import 'package:streamz/domain/services/platform_service.dart';
import 'package:streamz/domain/services/queue_service.dart';
import 'package:streamz/domain/services/remote_command_service.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/server/server_viewmodel.dart';
import 'package:streamz/presentation/shared/app_launch_splash.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Window Manager for Desktop
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      fullScreen: true,
      titleBarStyle: TitleBarStyle.hidden,
      center: true,
      backgroundColor: Color(0xFF060606),
      skipTaskbar: false,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setFullScreen(true);
    });
  }

  MediaKit.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await setupServiceLocator();
  final isAndroidTV = await sl<PlatformService>().isAndroidTV();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sl<ThemeService>()),
        ChangeNotifierProvider.value(value: sl<DownloadService>()),
        ChangeNotifierProvider.value(value: sl<RemoteCommandService>()),
        ChangeNotifierProvider.value(value: sl<QueueService>()),
        ChangeNotifierProvider.value(value: sl<ServerViewModel>()),
        ChangeNotifierProvider.value(value: sl<ClientViewModel>()),
      ],
      child: StreamzApp(isAndroidTV: isAndroidTV),
    ),
  );
}

// FIX: Must be StatefulWidget so we can register WidgetsBindingObserver.
// This is the only correct way to get AppLifecycleState callbacks at app root.
class StreamzApp extends StatefulWidget {
  const StreamzApp({super.key, required this.isAndroidTV});

  final bool isAndroidTV;

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
    final themeService = context.watch<ThemeService>();
    return MaterialApp.router(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(
        themeService.currentTheme,
        scaffoldTopColor: themeService.glowColor.color,
        cornerRadius: themeService.cornerRadius,
      ),
      routerConfig: appRouter,
      builder: (context, child) {
        final topColor = themeService.glowColor.color;
        return AppBackdrop(
          topColor: topColor,
          child: AppLaunchSplash(
            topColor: topColor,
            child: TVDeviceScope(
              isTelevision: widget.isAndroidTV,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      // [CRITICAL TV FIX]: Spread WidgetsApp.defaultShortcuts FIRST.
      // Omitting this deletes the native D-Pad Up/Down/Left/Right bindings.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            const ActivateIntent(),
        // Amazon Fire TV & certain Android TV "OK" buttons
        const SingleActivator(LogicalKeyboardKey.gameButtonA):
            const ActivateIntent(),
      },
    );
  }
}
