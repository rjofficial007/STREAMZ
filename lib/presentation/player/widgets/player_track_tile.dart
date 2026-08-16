import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streamz/core/theme/app_theme.dart';

/// PlayerTrackTile is an adaptive selection tile for media tracks (Audio, Subtitles)
/// and Broadcast Stations. It handles both touch (Mobile) and D-Pad (TV) interactions.
class PlayerTrackTile extends StatefulWidget {

  const PlayerTrackTile({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isTV = false,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isTV;

  @override
  State<PlayerTrackTile> createState() => _PlayerTrackTileState();
}

class _PlayerTrackTileState extends State<PlayerTrackTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    
    // Scale properties based on platform
    final verticalPadding = widget.isTV ? 32.0 : 14.0;
    final fontSize = widget.isTV ? 16.0 : 11.0;
    final iconSize = widget.isTV ? 24.0 : 12.0;
    final scale = _focused ? 1.02 : 1.0;

    return Focus(
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v && widget.isTV) handleTVFocusScroll(v, context);
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
            decoration: BoxDecoration(
              color: _focused 
                  ? tokens.textPrimary 
                  : (widget.isActive ? tokens.textPrimary.withValues(alpha: 0.05) : Colors.transparent),
              border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.dmMono(
                      color: _focused 
                          ? tokens.background 
                          : (widget.isActive ? tokens.textPrimary : tokens.textSecondary),
                      fontSize: fontSize,
                      fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
                      letterSpacing: widget.isTV ? 2 : 1,
                    ),
                  ),
                ),
                if (widget.isActive)
                  Icon(
                    LucideIcons.check, 
                    color: _focused ? tokens.background : tokens.textPrimary, 
                    size: iconSize
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
