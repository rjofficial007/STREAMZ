import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/server/server_viewmodel.dart';
import 'package:streamz/widget/remote_trackpad.dart';

class RemoteInputRelayScreen extends StatefulWidget {
  const RemoteInputRelayScreen({super.key, this.isServerMode = false});
  final bool isServerMode;

  @override
  State<RemoteInputRelayScreen> createState() => _RemoteInputRelayScreenState();
}

class _RemoteInputRelayScreenState extends State<RemoteInputRelayScreen> {
  final _textCtrl = TextEditingController();
  Offset _accumulatedDelta = Offset.zero;
  static const double _moveThreshold = 25.0;

  void _sendNav(String action) {
    if (widget.isServerMode) {
      context.read<ServerViewModel>().broadcastCommand('nav', action);
    } else {
      context.read<ClientViewModel>().sendNav(action);
    }
  }

  void _sendText(String text) {
    if (widget.isServerMode) {
      context.read<ServerViewModel>().broadcastCommand('nav', 'text', value: text);
    } else {
      context.read<ClientViewModel>().sendText(text);
    }
  }

  void _sendIntercom(String text) {
    if (widget.isServerMode && text.isNotEmpty) {
      context.read<ServerViewModel>().sendIntercom(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientVM = !widget.isServerMode ? context.watch<ClientViewModel>() : null;
    final serverVM = widget.isServerMode ? context.watch<ServerViewModel>() : null;

    final targetLabel = widget.isServerMode 
        ? 'TARGET: ALL_CONNECTED_NODES (${serverVM?.connectedClients ?? 0})'
        : 'TARGET: ${clientVM?.targetIp}';

    return Scaffold(
      backgroundColor: DS.bg,
      appBar: AppBar(
        backgroundColor: DS.surface1,
        title: Text(
          widget.isServerMode ? 'SERVER_REMOTE_RELAY' : 'REMOTE_RELAY',
          style: DS.labelLg.copyWith(letterSpacing: 4),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DS.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              targetLabel,
              style: DS.labelSm.copyWith(color: DS.success),
            ),
            const SizedBox(height: DS.s32),
            
            // Trackpad
            RemoteTrackpad(
              onMove: (delta) {
                _accumulatedDelta += delta;

                if (_accumulatedDelta.dx > _moveThreshold) {
                  _sendNav('right');
                  _accumulatedDelta = Offset(0, _accumulatedDelta.dy);
                } else if (_accumulatedDelta.dx < -_moveThreshold) {
                  _sendNav('left');
                  _accumulatedDelta = Offset(0, _accumulatedDelta.dy);
                }

                if (_accumulatedDelta.dy > _moveThreshold) {
                  _sendNav('down');
                  _accumulatedDelta = Offset(_accumulatedDelta.dx, 0);
                } else if (_accumulatedDelta.dy < -_moveThreshold) {
                  _sendNav('up');
                  _accumulatedDelta = Offset(_accumulatedDelta.dx, 0);
                }
              },
              onTap: () => _sendNav('enter'),
            ),
            
            const SizedBox(height: DS.s32),
            
            // Text Input
            TextField(
              controller: _textCtrl,
              style: DS.bodyLg.copyWith(color: DS.textPrimary),
              decoration: InputDecoration(
                labelText: 'TYPE TO TARGETS...',
                labelStyle: DS.labelSm,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isServerMode)
                      IconButton(
                        icon: const Icon(LucideIcons.megaphone, color: DS.warning),
                        tooltip: 'BROADCAST ALERT',
                        onPressed: () {
                          _sendIntercom(_textCtrl.text);
                          _textCtrl.clear();
                        },
                      ),
                    IconButton(
                      icon: const Icon(LucideIcons.send, color: DS.accent),
                      onPressed: () {
                        _sendText(_textCtrl.text);
                        _textCtrl.clear();
                      },
                    ),
                  ],
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: DS.borderDefault),
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: DS.accent),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onSubmitted: (v) {
                _sendText(v);
                _textCtrl.clear();
              },
            ),
            
            const SizedBox(height: DS.s48),
            
            // Grid of Navigation Controls
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              children: [
                _NavBtn(icon: LucideIcons.chevronLeft, label: 'BACK', onTap: () => _sendNav('back')),
                _NavBtn(icon: LucideIcons.chevronUp, label: 'UP', onTap: () => _sendNav('up')),
                _NavBtn(icon: LucideIcons.home, label: 'HOME', onTap: () => _sendNav('home')),
                
                _NavBtn(icon: LucideIcons.chevronLeft, label: 'LEFT', onTap: () => _sendNav('left')),
                _NavBtn(icon: LucideIcons.circle, label: 'ENTER', onTap: () => _sendNav('enter')),
                _NavBtn(icon: LucideIcons.chevronRight, label: 'RIGHT', onTap: () => _sendNav('right')),
                
                _NavBtn(icon: LucideIcons.info, label: 'INFO', onTap: () => _sendNav('info')),
                _NavBtn(icon: LucideIcons.chevronDown, label: 'DOWN', onTap: () => _sendNav('down')),
                _NavBtn(icon: LucideIcons.menu, label: 'MENU', onTap: () => _sendNav('menu')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {

  const _NavBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Container(
        color: DS.surface1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: DS.accent, size: 20),
            const SizedBox(height: 8),
            Text(label, style: DS.labelSm.copyWith(fontSize: 8)),
          ],
        ),
      ),
    );
}
