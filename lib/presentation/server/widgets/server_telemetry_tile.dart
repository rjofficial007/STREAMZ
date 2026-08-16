import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/domain/models/stream_session.dart';
import 'package:streamz/presentation/server/server_dashboard.dart';

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
            : (_isFocused ? tokens.textPrimary.withValues(alpha: 0.1) : tokens.surface1.withValues(alpha: 0.4)),
        border: Border(
          bottom: BorderSide(color: widget.isTarget || _isFocused ? tokens.accent : tokens.border.withValues(alpha: 0.15)),
          top: widget.isFirst 
              ? BorderSide(color: widget.isTarget || _isFocused ? tokens.accent : tokens.border.withValues(alpha: 0.15)) 
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Session Preview (Snapshot or Icon)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.surface2,
              border: Border.all(color: widget.isTarget || _isFocused ? tokens.accent : tokens.border.withValues(alpha: 0.15)),
            ),
            child: widget.session.snapshot != null
                ? Image.memory(
                    base64Decode(widget.session.snapshot!),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : Icon(
                    widget.session.mediaType == 'video' 
                        ? LucideIcons.film 
                        : (widget.session.mediaType == 'audio' ? LucideIcons.activity : LucideIcons.download),
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
                  widget.session.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    color: tokens.textPrimary, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'NODE: ${widget.session.clientId.toUpperCase()}', 
                  style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 1)
                ),
                if (safeProgress > 0) ...[
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(height: 1, color: tokens.surface2),
                      FractionallySizedBox(
                        widthFactor: safeProgress,
                        child: Container(height: 1, color: tokens.telemetry),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Remote Control Trigger
          _BrutalistIconButton(
            icon: LucideIcons.gamepad2,
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: tokens.background,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              isScrollControlled: true,
              builder: (_) => UniversalRemoteSheet(targetId: widget.session.clientId),
            ),
          ),
        ],
      ),
    );

    return Draggable<String>(
      data: widget.session.clientId,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.surface1,
            border: Border.all(color: tokens.accent),
          ),
          child: Text(
            widget.session.title.toUpperCase(), 
            style: GoogleFonts.dmMono(color: tokens.accent, fontSize: 10)
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
    );
  }
}

/// Private helper icon button with Brutalist styling.
class _BrutalistIconButton extends StatefulWidget {
  const _BrutalistIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_BrutalistIconButton> createState() => _BrutalistIconButtonState();
}

class _BrutalistIconButtonState extends State<_BrutalistIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Focus(
        onFocusChange: (v) {
          setState(() => _isFocused = v);
          handleTVFocusScroll(v, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _isFocused = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isFocused ? tokens.textPrimary : Colors.transparent,
              border: Border.all(color: _isFocused ? tokens.textPrimary : Colors.transparent),
            ),
            child: Icon(
              widget.icon, 
              color: _isFocused ? tokens.background : tokens.textPrimary, 
              size: 20
            ),
          ),
        ),
      ),
    );
  }
}
