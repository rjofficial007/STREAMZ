import 'package:flutter/material.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// Focusable, accessible player action with a 48-pixel minimum hit target.
class PlayerActionButton extends StatefulWidget {
  const PlayerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.size,
    this.isTV = false,
    this.isPrimary = false,
    this.isDestructive = false,
    this.focusNode,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final bool isTV;
  final bool isPrimary;
  final bool isDestructive;
  final FocusNode? focusNode;

  @override
  State<PlayerActionButton> createState() => _PlayerActionButtonState();
}

class _PlayerActionButtonState extends State<PlayerActionButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final targetSize = widget.size < 48 ? 48.0 : widget.size;
    final iconSize = (widget.size * 0.5).clamp(18.0, 32.0).toDouble();
    final active = _focused || _hovered;
    final isPrimary = widget.isPrimary && !active;

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: Focus(
          focusNode: widget.focusNode,
          onFocusChange: (focused) {
            setState(() => _focused = focused);
            if (focused && widget.isTV) handleTVFocusScroll(focused, context);
          },
          onKeyEvent: (_, event) =>
              handleTVSelectKey(event, widget.onPressed),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(DS.radiusMd),
              onTap: widget.onPressed,
              onHover: (hovered) => setState(() => _hovered = hovered),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                width: targetSize,
                height: targetSize,
                decoration: BoxDecoration(
                  color: active
                      ? tokens.surface3
                      : isPrimary
                      ? tokens.textPrimary
                      : tokens.surface1.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  border: Border.all(
                    color: _focused
                        ? tokens.focusColor
                        : tokens.border.withValues(alpha: 0.65),
                    width: _focused ? DS.focusWidth : 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: iconSize,
                    color: isPrimary
                        ? tokens.background
                        : widget.isDestructive
                        ? tokens.error
                        : tokens.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
