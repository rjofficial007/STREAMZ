import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/server/server_viewmodel.dart';
import 'package:streamz/presentation/shared/app_summary_components.dart';

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
          AppSummaryHeader(
            title: 'Server',
            titleStyle: AppTextStyles.titleLarge.copyWith(
              color: tokens.textPrimary,
              fontWeight: AppTextStyles.titleFontWeight,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ServerStatusDot(isOnline: widget.state.isRunning),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.state.isInitializing
                        ? 'Starting'
                        : widget.state.isRunning
                        ? 'Running'
                        : 'Stopped',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: widget.state.isRunning
                          ? tokens.success
                          : tokens.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
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
                  widget.state.serverIp,
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
                  'Devices',
                  widget.state.connectedClients.toString(),
                  tokens.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.state.speedUpdates,
                  builder: (context, speed, _) => _legend(
                    'Speed',
                    '${speed.toStringAsFixed(1)} MB/s',
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
                                  style: AppTextStyles.caption.copyWith(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
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

  Widget _legend(String label, String value, Color color) => AppSummaryLegend(
    label: label,
    value: value,
    markerColor: color,
  );
}

/// Static server status indicator.
class ServerStatusDot extends StatelessWidget {
  const ServerStatusDot({super.key, required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = isOnline ? tokens.success : tokens.textMuted;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isOnline
            ? [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 8)]
            : null,
      ),
    );
  }
}
