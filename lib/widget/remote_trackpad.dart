import 'package:flutter/material.dart';
import 'package:streamz/core/theme/design_tokens.dart';

class RemoteTrackpad extends StatefulWidget {
  final Function(Offset delta) onMove;
  final VoidCallback onTap;

  const RemoteTrackpad({super.key, required this.onMove, required this.onTap});

  @override
  State<RemoteTrackpad> createState() => _RemoteTrackpadState();
}

class _RemoteTrackpadState extends State<RemoteTrackpad> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => setState(() => _active = true),
      onPanEnd: (_) => setState(() => _active = false),
      onPanUpdate: (d) => widget.onMove(d.delta),
      onTap: widget.onTap,
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _active ? DS.surface3 : DS.surface2,
          border: Border.all(color: DS.borderStrong, width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app,
                size: 48,
                color: _active ? DS.accent : DS.textMuted,
              ),
              const SizedBox(height: DS.s16),
              Text(
                'TRACKPAD // SWIPE TO MOVE',
                style: DS.labelMd.copyWith(color: DS.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
