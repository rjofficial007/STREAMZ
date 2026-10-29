import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/stream_session.dart';
import 'package:streamz/presentation/server/server_dashboard.dart';
import 'package:streamz/presentation/shared/app_bottom_sheet.dart';

/// _TelemetryTile displays real-time playback status for a single connected node.
/// It supports drag-and-drop for session "teleporting" (handing off playback).
class ServerTelemetryTile extends StatefulWidget {
  const ServerTelemetryTile({
    super.key,
    required this.session,
    required this.isMobile,
    required this.isFirst,
    this.isTarget = false,
  });
  final StreamSession session;
  final bool isMobile;
  final bool isFirst;
  final bool isTarget;

  @override
  State<ServerTelemetryTile> createState() => _ServerTelemetryTileState();
}

class _ServerTelemetryTileState extends State<ServerTelemetryTile> {
  bool _isFocused = false;
  Uint8List? _snapshotBytes;

  @override
  void initState() {
    super.initState();
    _decodeSnapshot(widget.session.snapshot);
  }

  @override
  void didUpdateWidget(covariant ServerTelemetryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.snapshot != widget.session.snapshot) {
      _decodeSnapshot(widget.session.snapshot);
    }
  }

  void _decodeSnapshot(String? snapshot) {
    if (snapshot == null) {
      _snapshotBytes = null;
      return;
    }
    try {
      _snapshotBytes = base64Decode(snapshot);
    } on FormatException {
      _snapshotBytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // Ensure progress is a valid double between 0 and 1.
    final safeProgress = widget.session.progress.isFinite
        ? widget.session.progress.clamp(0.0, 1.0)
        : 0.0;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: widget.isTarget
            ? tokens.accent.withValues(alpha: 0.2)
            : (_isFocused
                  ? tokens.surface3
                  : tokens.surface1.withValues(alpha: 0.92)),
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(
          color: widget.isTarget || _isFocused
              ? tokens.focusColor
              : tokens.border.withValues(alpha: widget.isFirst ? 0.7 : 0.55),
          width: widget.isTarget || _isFocused ? DS.focusWidth : 1,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: DS.s16,
        vertical: widget.isMobile ? DS.s12 : DS.s16,
      ),
      child: Row(
        children: [
          // Session Preview (Snapshot or Icon)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(
                color: widget.isTarget || _isFocused
                    ? tokens.accent
                    : tokens.border.withValues(alpha: 0.15),
              ),
            ),
            child: _snapshotBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                    child: Image.memory(
                      _snapshotBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => Icon(
                        LucideIcons.imageOff,
                        color: tokens.textMuted,
                        size: 20,
                      ),
                    ),
                  )
                : Icon(
                    widget.session.mediaType == 'video'
                        ? LucideIcons.film
                        : (widget.session.mediaType == 'audio'
                              ? LucideIcons.activity
                              : LucideIcons.download),
                    color: tokens.textSecondary,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          // Metadata and Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connected device · ${widget.session.clientId}',
                  style: AppTextStyles.caption.copyWith(
                    color: tokens.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (safeProgress > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                    child: LinearProgressIndicator(
                      value: safeProgress,
                      minHeight: 3,
                      backgroundColor: tokens.surface2,
                      valueColor: AlwaysStoppedAnimation(tokens.telemetry),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Remote Control Trigger
          IconButton(
            tooltip: 'Open remote controls',
            style: IconButton.styleFrom(
              backgroundColor: tokens.surface2,
              foregroundColor: tokens.textSecondary,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(LucideIcons.gamepad2),
            onPressed: () => showAppBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  UniversalRemoteSheet(targetId: widget.session.clientId),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s4),
      child: Draggable<String>(
        data: widget.session.clientId,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(DS.s16),
            decoration: BoxDecoration(
              color: tokens.surface1,
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(color: tokens.borderStrong),
            ),
            child: Text(
              widget.session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(color: tokens.textPrimary),
            ),
          ),
        ),
        child: Focus(
          onFocusChange: (v) {
            setState(() => _isFocused = v);
            handleTVFocusScroll(v, context);
          },
          child: tile,
        ),
      ),
    );
  }
}
