// core/navigation/app_router.dart
// ============================================================================
// STREAMZ — GoRouter Configuration
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamz/core/theme/app_theme.dart';
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
import 'package:streamz/presentation/shared/app_state_view.dart';
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
      builder: (context, state) => _buildPlayerRoute(context, state),
    ),
    GoRoute(
      path: '/tv-player',
      builder: (context, state) =>
          _buildPlayerRoute(context, state, isTV: true),
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

Widget _buildPlayerRoute(
  BuildContext context,
  GoRouterState state, {
  bool isTV = false,
}) {
  final extra = state.extra;
  if (extra is! Map) return const _MissingPlayerDataScreen();

  final rawItems = extra['items'];
  if (rawItems is! List ||
      rawItems.isEmpty ||
      rawItems.any((item) => item is! MediaItem)) {
    return const _MissingPlayerDataScreen();
  }
  final items = rawItems.cast<MediaItem>();

  final requestedIndex = extra['startIndex'];
  final startIndex = requestedIndex is int
      ? requestedIndex.clamp(0, items.length - 1).toInt()
      : 0;
  final isPathBased = extra['isPathBased'] is bool
      ? extra['isPathBased'] as bool
      : false;
  final startOffset = extra['startOffset'] is Duration
      ? extra['startOffset'] as Duration
      : null;
  final autoPlay = extra['autoPlay'] is bool
      ? extra['autoPlay'] as bool
      : true;

  if (isTV) {
    return TVPlayerScreen(
      items: items,
      startIndex: startIndex,
      isPathBased: isPathBased,
      startOffset: startOffset,
      autoPlay: autoPlay,
    );
  }
  return PlayerScreen(
    items: items,
    startIndex: startIndex,
    isPathBased: isPathBased,
    startOffset: startOffset,
    autoPlay: autoPlay,
  );
}

class _MissingPlayerDataScreen extends StatelessWidget {
  const _MissingPlayerDataScreen();

  @override
  Widget build(BuildContext context) => AppScaffold(
    body: SafeArea(
      child: AppStateView(
        kind: AppStateKind.error,
        title: 'Unable to open media',
        description: 'Playback details are missing. Choose the item again.',
        icon: Icons.video_library_outlined,
        actionLabel: 'Go back',
        onAction: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
    ),
  );
}
