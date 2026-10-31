import 'package:flutter/material.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/client_connection_phase.dart';

class ClientConnectionNotice extends StatelessWidget {
  const ClientConnectionNotice({
    super.key,
    required this.phase,
    required this.onReconnect,
    required this.onRetry,
    this.error,
  });

  final ClientConnectionPhase phase;
  final String? error;
  final VoidCallback onReconnect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (phase == ClientConnectionPhase.connected ||
        phase == ClientConnectionPhase.idle) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final title = switch (phase) {
      ClientConnectionPhase.discovering => 'Finding server',
      ClientConnectionPhase.connecting => 'Connecting to server',
      ClientConnectionPhase.connected || ClientConnectionPhase.idle => '',
      ClientConnectionPhase.degraded => 'Library refresh failed',
      ClientConnectionPhase.reconnecting => 'Reconnecting to server',
      ClientConnectionPhase.failed => 'Server connection failed',
    };
    final icon = switch (phase) {
      ClientConnectionPhase.degraded => Icons.sync_problem_rounded,
      ClientConnectionPhase.failed => Icons.wifi_off_rounded,
      ClientConnectionPhase.discovering ||
      ClientConnectionPhase.connecting ||
      ClientConnectionPhase.reconnecting => Icons.sync_rounded,
      ClientConnectionPhase.connected ||
      ClientConnectionPhase.idle => Icons.wifi_rounded,
    };
    final description = switch (phase) {
      ClientConnectionPhase.degraded =>
        error ?? 'Showing saved media while trying to refresh.',
      ClientConnectionPhase.reconnecting =>
        'Your library and playback session will resync when the server returns.',
      ClientConnectionPhase.failed =>
        error ?? 'Reconnect to browse shared media.',
      _ => error,
    };
    final actionLabel = switch (phase) {
      ClientConnectionPhase.degraded => 'Retry',
      ClientConnectionPhase.failed => 'Reconnect',
      _ => null,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            DS
                .hPad(MediaQuery.sizeOf(context).width)
                .clamp(DS.s16, DS.s48)
                .toDouble(),
            DS.s8,
            DS
                .hPad(MediaQuery.sizeOf(context).width)
                .clamp(DS.s16, DS.s48)
                .toDouble(),
            DS.s8,
          ),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(DS.s16),
              decoration: BoxDecoration(
                color: tokens.surface1,
                borderRadius: BorderRadius.circular(DS.radiusLg),
                border: Border.all(color: tokens.border.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: tokens.accent, size: 22),
                  const SizedBox(width: DS.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: tokens.textPrimary),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: DS.s4),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: DS.s12),
                    OutlinedButton(
                      onPressed: phase == ClientConnectionPhase.degraded
                          ? onRetry
                          : onReconnect,
                      child: Text(actionLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
