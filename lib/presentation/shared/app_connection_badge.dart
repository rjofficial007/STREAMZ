import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/client_connection_phase.dart';

/// Compact, responsive connection summary for paired client screens.
class AppConnectionBadge extends StatelessWidget {
  const AppConnectionBadge({
    super.key,
    required this.hostIp,
    this.itemCount,
    this.isConnected = true,
    this.connectionPhase,
  });

  final String hostIp;
  final int? itemCount;
  final bool isConnected;
  final ClientConnectionPhase? connectionPhase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final phase =
        connectionPhase ??
        (isConnected
            ? ClientConnectionPhase.connected
            : ClientConnectionPhase.idle);
    final status = switch (phase) {
      ClientConnectionPhase.idle => 'Disconnected',
      ClientConnectionPhase.discovering => 'Finding server',
      ClientConnectionPhase.connecting => 'Connecting',
      ClientConnectionPhase.connected => 'Connected',
      ClientConnectionPhase.degraded => 'Sync issue',
      ClientConnectionPhase.reconnecting => 'Reconnecting',
      ClientConnectionPhase.failed => 'Connection failed',
    };
    final statusColor = switch (phase) {
      ClientConnectionPhase.connected => tokens.success,
      ClientConnectionPhase.degraded ||
      ClientConnectionPhase.failed => tokens.textMuted,
      _ => tokens.accent,
    };
    final statusIcon = switch (phase) {
      ClientConnectionPhase.connected => Icons.wifi_rounded,
      ClientConnectionPhase.idle ||
      ClientConnectionPhase.failed => Icons.wifi_off_rounded,
      _ => Icons.sync_rounded,
    };
    final detail = [
      if (hostIp.isNotEmpty) hostIp,
      if (itemCount != null) '$itemCount media items',
    ].join(' · ');

    return Semantics(
      container: true,
      label: detail.isEmpty ? status : '$status: $detail',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280, minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s8,
        ),
        decoration: BoxDecoration(
          color: tokens.surface1.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(DS.radiusLg),
          border: Border.all(color: tokens.border.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: DS.s12),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
