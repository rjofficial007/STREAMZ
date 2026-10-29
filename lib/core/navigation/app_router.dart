// core/navigation/app_router.dart
// ============================================================================
// STREAMZ — GoRouter Configuration
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_connect_screen.dart';
import 'package:streamz/presentation/client/interface_selection_screen.dart';
import 'package:streamz/presentation/client/qr_scanner_screen.dart';
import 'package:streamz/presentation/home/permission_screen.dart';
import 'package:streamz/presentation/home/role_selection_screen.dart';
import 'package:streamz/presentation/mobile/file_manager.dart';
import 'package:streamz/presentation/mobile/mobile_selection_screen.dart';
import 'package:streamz/presentation/mobile/modern_mobile_ui.dart';
import 'package:streamz/presentation/player/player_screen.dart';
import 'package:streamz/presentation/server/server_dashboard.dart';
import 'package:streamz/presentation/settings/app_settings_screen.dart';
import 'package:streamz/presentation/shared/remote_input_relay_screen.dart';
import 'package:streamz/presentation/tv/tv_file_manager.dart';
import 'package:streamz/presentation/tv/tv_home_screen.dart';
import 'package:streamz/presentation/tv/tv_player_screen.dart';
import 'package:streamz/presentation/tv/tv_selection_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const AppSettingsScreen(),
    ),
    GoRoute(
      path: '/server',
      builder: (context, state) => const ServerDashboard(),
    ),
    GoRoute(
      path: '/server/permissions',
      builder: (context, state) => const PermissionScreen(),
    ),
    GoRoute(
      path: '/client/connect',
      builder: (context, state) => const ClientConnectScreen(),
    ),
    GoRoute(
      path: '/client/interface',
      builder: (context, state) => const InterfaceSelectionScreen(),
    ),
    GoRoute(
      path: '/client/tv',
      builder: (context, state) => const TVSelectionScreen(),
    ),
    GoRoute(
      path: '/client/tv/home',
      builder: (context, state) => const TVHomeScreen(),
    ),
    GoRoute(
      path: '/client/tv/files',
      builder: (context, state) => const TVFileManagerScreen(),
    ),
    GoRoute(
      path: '/client/mobile',
      builder: (context, state) => const MobileSelectionScreen(),
    ),
    GoRoute(
      path: '/client/mobile/ui',
      builder: (context, state) => const ModernMobileUIScreen(),
    ),
    GoRoute(
      path: '/client/mobile/files',
      builder: (context, state) => const SamsungFileManagerScreen(),
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>;
        return PlayerScreen(
          items: extras['items'] as List<MediaItem>,
          startIndex: extras['startIndex'] as int,
          isPathBased: extras['isPathBased'] as bool? ?? false,
          startOffset: extras['startOffset'] as Duration?,
          autoPlay: extras['autoPlay'] as bool? ?? true,
        );
      },
    ),
    GoRoute(
      path: '/tv-player',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>;
        return TVPlayerScreen(
          items: extras['items'] as List<MediaItem>,
          startIndex: extras['startIndex'] as int,
          isPathBased: extras['isPathBased'] as bool? ?? false,
          startOffset: extras['startOffset'] as Duration?,
          autoPlay: extras['autoPlay'] as bool? ?? true,
        );
      },
    ),
    GoRoute(
      path: '/relay',
      builder: (context, state) => const RemoteInputRelayScreen(),
    ),
    GoRoute(
      path: '/qr-scanner',
      builder: (context, state) => const QRScannerScreen(),
    ),
  ],
);
