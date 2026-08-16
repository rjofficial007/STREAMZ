import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:streamz/core/theme/app_theme.dart';

/// LowFiIndicator notifies the user when the stream has entered "Low-Fi" recovery mode.
/// This happens when the local network signal is too weak for high-bitrate playback.
class LowFiIndicator extends StatelessWidget {

  const LowFiIndicator({super.key, this.isTV = false});
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    
    final bottomPadding = isTV ? 200.0 : 100.0;
    final leftPadding = isTV ? 60.0 : 20.0;
    final fontSize = isTV ? 14.0 : 8.0;
    final letterSpacing = isTV ? 4.0 : 2.0;

    return Positioned(
      bottom: bottomPadding,
      left: leftPadding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: tokens.warning,
        child: Text(
          isTV ? 'LOW-FI SIGNAL RECOVERY ACTIVATED' : 'LOW-FI SIGNAL RECOVERY',
          style: GoogleFonts.dmMono(
            color: tokens.background, 
            fontSize: fontSize, 
            fontWeight: FontWeight.bold, 
            letterSpacing: letterSpacing
          ),
        ),
      ),
    );
  }
}
