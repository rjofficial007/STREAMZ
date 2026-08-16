import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streamz/core/theme/app_theme.dart';

/// PlayerSyncTile provides controls to adjust audio or subtitle sync offsets.
/// It features a Brutalist "minus/plus" control scheme that adapts to TV and Mobile.
class PlayerSyncTile extends StatelessWidget {

  const PlayerSyncTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isTV = false,
  });
  final String label;
  final double value;
  final Function(double) onChanged;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    
    // Scale properties based on platform
    final padding = isTV ? 40.0 : 16.0;
    final labelSize = isTV ? 14.0 : 8.0;
    final valueSize = isTV ? 32.0 : 16.0;
    final btnSize = isTV ? 64.0 : 32.0;
    final spacing = isTV ? 24.0 : 12.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, 
            style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: labelSize, letterSpacing: 2)
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              _SyncActionBtn(
                icon: LucideIcons.minus, 
                size: btnSize, 
                onTap: () => onChanged(value - 0.1)
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${value.toStringAsFixed(1)}S',
                    style: GoogleFonts.dmMono(
                      color: tokens.textPrimary, 
                      fontSize: valueSize, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
              _SyncActionBtn(
                icon: LucideIcons.plus, 
                size: btnSize, 
                onTap: () => onChanged(value + 0.1)
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Private internal button for sync adjustments with focus support.
class _SyncActionBtn extends StatefulWidget {

  const _SyncActionBtn({required this.icon, required this.size, required this.onTap});
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  State<_SyncActionBtn> createState() => _SyncActionBtnState();
}

class _SyncActionBtnState extends State<_SyncActionBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _focused ? tokens.textPrimary : Colors.transparent,
            border: Border.all(
              color: _focused ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15)
            ),
          ),
          child: Icon(
            widget.icon, 
            color: _focused ? tokens.background : tokens.textPrimary, 
            size: widget.size * 0.5
          ),
        ),
      ),
    );
  }
}
