import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/presentation/server/server_viewmodel.dart';

/// ServerEngineCard provides a high-level summary of the server's operational status.
/// It includes IP address, uptime status, connected nodes, and real-time bandwidth.
class ServerEngineCard extends StatefulWidget {
  const ServerEngineCard({super.key, required this.state, required this.isMobile});
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
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.4),
        border: Border.symmetric(
          horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ENGINE ANALYSIS',
                style: GoogleFonts.barlowCondensed(
                  color: tokens.textPrimary, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1
                ),
              ),
              ServerBlinkingDot(isOnline: widget.state.isRunning),
            ],
          ),
          SizedBox(height: widget.isMobile ? 16 : 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IP ADDRESS', 
                      style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.state.serverIp.toUpperCase(),
                        style: GoogleFonts.dmMono(
                          color: tokens.textPrimary, 
                          fontSize: 14, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'UPTIME', 
                      style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 1)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LIVE',
                      style: GoogleFonts.dmMono(
                        color: tokens.textPrimary, 
                        fontSize: 14, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: widget.isMobile ? 20 : 24),
          // Operational Health Bar
          Stack(
            children: [
              Container(height: 8, color: tokens.surface2),
              if (widget.state.isRunning)
                FractionallySizedBox(
                  widthFactor: 1.0,
                  child: Container(height: 8, color: tokens.accent),
                ),
            ],
          ),
          SizedBox(height: widget.isMobile ? 16 : 20),
          Row(
            children: [
              Expanded(child: _legend(context, 'NODES', widget.state.connectedClients.toString(), tokens.accent)),
              const SizedBox(width: 16),
              Expanded(child: _legend(context, 'SPEED', '${widget.state.currentSpeedMb.toStringAsFixed(1)} MB/S', tokens.telemetry)),
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
                          widget.state.isRunning ? widget.state.stopServer() : widget.state.startServer();
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
                      widget.state.isInitializing ? null : () => widget.state.isRunning ? widget.state.stopServer() : widget.state.startServer()
                    ),
                    child: InkWell(
                      onTap: widget.state.isInitializing 
                          ? null 
                          : () => widget.state.isRunning ? widget.state.stopServer() : widget.state.startServer(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _btnFocused ? tokens.textPrimary : Colors.transparent,
                          border: Border.all(color: tokens.textPrimary),
                        ),
                        child: Center(
                          child: widget.state.isInitializing
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  widget.state.isRunning ? 'STOP ENGINE' : 'START ENGINE',
                                  style: GoogleFonts.dmMono(
                                    color: _btnFocused ? tokens.background : tokens.textPrimary, 
                                    fontSize: 11, 
                                    fontWeight: FontWeight.bold, 
                                    letterSpacing: 2
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

  Widget _legend(BuildContext context, String label, String value, Color color) {
    final tokens = context.tokens;
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10)),
        ),
        Text(
          value,
          style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textPrimary),
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

class _ServerBlinkingDotState extends State<ServerBlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (!widget.isOnline) return Container(width: 8, height: 8, color: tokens.textMuted.withValues(alpha: 0.3));
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
