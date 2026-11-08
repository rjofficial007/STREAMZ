import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';

class RemoteTrackpad extends StatefulWidget {

  const RemoteTrackpad({super.key, required this.onMove, required this.onTap});
  final Function(Offset delta) onMove;
  final VoidCallback onTap;

  @override
  State<RemoteTrackpad> createState() => _RemoteTrackpadState();
}

class _RemoteTrackpadState extends State<RemoteTrackpad> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label: 'Remote trackpad. Swipe to move and tap to select.',
      child: GestureDetector(
        onPanStart: (_) => setState(() => _active = true),
        onPanEnd: (_) => setState(() => _active = false),
        onPanCancel: () => setState(() => _active = false),
        onPanUpdate: (d) => widget.onMove(d.delta),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _active ? tokens.surface3 : tokens.surface1,
            borderRadius: BorderRadius.circular(DS.radiusLg),
            border: Border.all(
              color: _active ? tokens.accent : tokens.border,
              width: _active ? 2 : 1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app,
                  size: 48,
                  color: _active ? tokens.accent : tokens.textMuted,
                ),
                const SizedBox(height: DS.s16),
                Text(
                  'Swipe to move · Tap to select',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
