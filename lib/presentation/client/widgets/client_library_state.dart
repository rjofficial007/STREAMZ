import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/domain/models/client_connection_phase.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';

/// Shared connection-aware loading, error, and empty states for client libraries.
class ClientLibraryStateView extends StatelessWidget {
  const ClientLibraryStateView({
    super.key,
    required this.isLoading,
    required this.connectionPhase,
    required this.onReconnect,
    this.error,
    this.onRefresh,
  });

  final bool isLoading;
  final ClientConnectionPhase connectionPhase;
  final String? error;
  final VoidCallback onReconnect;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AppStateView(
        kind: AppStateKind.loading,
        title: 'Loading shared media',
      );
    }

    final progressTitle = switch (connectionPhase) {
      ClientConnectionPhase.discovering => 'Finding server',
      ClientConnectionPhase.connecting => 'Connecting to server',
      ClientConnectionPhase.reconnecting => 'Reconnecting to server',
      _ => null,
    };
    if (progressTitle != null) {
      return AppStateView(
        kind: AppStateKind.loading,
        title: progressTitle,
        description: connectionPhase == ClientConnectionPhase.reconnecting
            ? 'Your connection will resume automatically.'
            : null,
      );
    }

    if (connectionPhase == ClientConnectionPhase.failed ||
        connectionPhase == ClientConnectionPhase.degraded ||
        connectionPhase == ClientConnectionPhase.idle) {
      final message = error?.trim();
      return AppStateView(
        kind: AppStateKind.error,
        title: connectionPhase == ClientConnectionPhase.degraded
            ? 'Shared media unavailable'
            : 'Server disconnected',
        description: message == null || message.isEmpty
            ? 'Reconnect to browse shared media.'
            : message,
        icon: AppIcons.wifiOff,
        actionLabel: connectionPhase == ClientConnectionPhase.degraded
            ? 'Retry'
            : 'Reconnect',
        onAction: connectionPhase == ClientConnectionPhase.degraded
            ? onRefresh ?? onReconnect
            : onReconnect,
      );
    }

    return const AppStateView(
      title: AppStrings.noSignals,
      description: 'No shared media is available from this server.',
    );
  }
}
