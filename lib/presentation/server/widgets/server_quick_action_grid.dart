import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:streamz/core/theme/app_theme.dart';

/// ServerQuickActionCard is a modular UI block for the server's command grid.
/// It handles hover and focus states for both mouse and TV navigation.
class ServerQuickActionCard extends StatefulWidget {

  const ServerQuickActionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<ServerQuickActionCard> createState() => _ServerQuickActionCardState();
}

class _ServerQuickActionCardState extends State<ServerQuickActionCard> {
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
            color: _isFocused ? tokens.textPrimary : tokens.background,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon, 
                  color: _isFocused ? tokens.background : tokens.textPrimary, 
                  size: 24
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.dmMono(
                    color: _isFocused ? tokens.background : tokens.textSecondary, 
                    fontSize: 9, 
                    letterSpacing: 1
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
