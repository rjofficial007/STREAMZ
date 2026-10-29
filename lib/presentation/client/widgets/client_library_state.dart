import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';

/// Shared loading, disconnected, and empty states for the mobile and TV library.
class ClientLibraryStateView extends StatelessWidget {
  const ClientLibraryStateView({
    super.key,
    required this.isLoading,
    required this.isConnected,
    required this.onReconnect,
    this.error,
  });

  final bool isLoading;
  final bool isConnected;
  final String? error;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AppStateView(
        kind: AppStateKind.loading,
        title: 'Loading shared media',
      );
    }

    if (!isConnected) {
      final message = error?.trim();
      return AppStateView(
        kind: AppStateKind.error,
        title: 'Server disconnected',
        description: message == null || message.isEmpty
            ? 'Reconnect to browse shared media.'
            : message,
        icon: AppIcons.wifiOff,
        actionLabel: 'Reconnect',
        onAction: onReconnect,
      );
    }

    return const AppStateView(
      title: AppStrings.noSignals,
      description: 'No shared media is available from this server.',
    );
  }
}
