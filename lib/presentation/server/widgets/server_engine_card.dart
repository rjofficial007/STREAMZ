import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/presentation/server/server_viewmodel.dart';
import 'package:streamz/core/theme/design_tokens.dart';

/// Compact server controls and live connection metrics for the dashboard.
class ServerEngineCard extends StatefulWidget {
  const ServerEngineCard({
    super.key,
    required this.state,
    required this.isMobile,
  });
  final ServerViewModel state;
  final bool isMobile;

  @override
  State<ServerEngineCard> createState() => _ServerEngineCardState();
}

class _ServerEngineCardState extends State<ServerEngineCard> {
  bool _btnFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DS.radius(20)),
        border: Border.all(color: tokens.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Server',
                style: AppTextStyles.titleLarge.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: AppTextStyles.titleFontWeight,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ServerBlinkingDot(isOnline: widget.state.isRunning),
                  const SizedBox(width: 8),
                  Text(
                    widget.state.isInitializing
                        ? 'Starting'
                        : widget.state.isRunning
                        ? 'Running'
                        : 'Stopped',
                    style: AppTextStyles.body.copyWith(
                      color: widget.state.isRunning
                          ? tokens.success
                          : tokens.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: widget.isMobile ? 16 : 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Server address',
                style: AppTextStyles.caption.copyWith(
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.state.serverIp.toUpperCase(),
                  style: AppTextStyles.body.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: widget.isMobile ? 16 : 20),
          Row(
            children: [
              Expanded(
                child: _legend(
                  context,
                  'NODES',
                  widget.state.connectedClients.toString(),
                  tokens.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.state.speedUpdates,
                  builder: (context, speed, _) => _legend(
                    context,
                    'SPEED',
                    '${speed.toStringAsFixed(1)} MB/S',
                    tokens.telemetry,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: widget.isMobile ? 16 : 24),
          // Master Kill/Start Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Actions(
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        if (!widget.state.isInitializing) {
                          widget.state.isRunning
                              ? widget.state.stopServer()
                              : widget.state.startServer();
                        }
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    onFocusChange: (v) {
                      setState(() => _btnFocused = v);
                      handleTVFocusScroll(v, context);
                    },
                    onKeyEvent: (_, ev) => handleTVSelectKey(
                      ev,
                      widget.state.isInitializing
                          ? null
                          : () => widget.state.isRunning
                                ? widget.state.stopServer()
                                : widget.state.startServer(),
                    ),
                    child: InkWell(
                      onTap: widget.state.isInitializing
                          ? null
                          : () => widget.state.isRunning
                                ? widget.state.stopServer()
                                : widget.state.startServer(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _btnFocused
                              ? tokens.surface3
                              : tokens.surface2,
                          borderRadius: BorderRadius.circular(DS.radius(14)),
                          border: Border.all(
                            color: _btnFocused
                                ? tokens.focusColor
                                : tokens.borderStrong,
                          ),
                        ),
                        child: Center(
                          child: widget.state.isInitializing
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  widget.state.isRunning
                                      ? 'Stop server'
                                      : 'Start server',
                                  style: AppTextStyles.caption.copyWith(color: _btnFocused
                                        ? tokens.background
                                        : tokens.textPrimary, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final tokens = context.tokens;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: tokens.textMuted),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500, color: tokens.textPrimary),
        ),
      ],
    );
  }
}

/// Blinking status indicator for live signals.
class ServerBlinkingDot extends StatefulWidget {
  const ServerBlinkingDot({super.key, required this.isOnline});
  final bool isOnline;

  @override
  State<ServerBlinkingDot> createState() => _ServerBlinkingDotState();
}

class _ServerBlinkingDotState extends State<ServerBlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (!widget.isOnline) {
      return Container(
        width: 8,
        height: 8,
        color: tokens.textMuted.withValues(alpha: 0.3),
      );
    }
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: tokens.success,
          boxShadow: [BoxShadow(color: tokens.success, blurRadius: 4)],
        ),
      ),
    );
  }
}
