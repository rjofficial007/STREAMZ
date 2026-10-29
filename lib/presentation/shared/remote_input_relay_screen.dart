import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/server/server_viewmodel.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
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
      context.read<ServerViewModel>().broadcastCommand(
        'nav',
        'text',
        value: text,
      );
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
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetLabel = widget.isServerMode
        ? '${context.select<ServerViewModel, int>((vm) => vm.connectedClients)} connected devices'
        : context.select<ClientViewModel, String>((vm) => vm.targetIp);

    return AppScaffold(
      appBar: AppBar(
        title: Text(
          'Remote relay',
          style: AppTextStyles.titleLarge.copyWith(
            color: context.tokens.textPrimary,
            fontWeight: AppTextStyles.titleFontWeight,
          ),
        ),
        leading: AppBackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DS.s16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Builder(
              builder: (context) {
                final tokens = context.tokens;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(DS.s16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: tokens.surface2,
                                borderRadius: BorderRadius.circular(DS.radiusMd),
                              ),
                              child: Icon(
                                LucideIcons.monitor,
                                color: tokens.textSecondary,
                              ),
                            ),
                            const SizedBox(width: DS.s16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Connected target',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: tokens.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: DS.s4),
                                  Text(
                                    targetLabel,
                                    style: AppTextStyles.supporting.copyWith(
                                      color: tokens.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: DS.s20),
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
                    const SizedBox(height: DS.s20),
                    TextField(
                      controller: _textCtrl,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Send text to target',
                        filled: true,
                        fillColor: tokens.surface1,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isServerMode)
                              IconButton(
                                icon: const Icon(LucideIcons.megaphone),
                                color: tokens.warning,
                                tooltip: 'Send broadcast alert',
                                onPressed: () {
                                  _sendIntercom(_textCtrl.text);
                                  _textCtrl.clear();
                                },
                              ),
                            IconButton(
                              icon: const Icon(LucideIcons.send),
                              color: tokens.accent,
                              tooltip: 'Send text',
                              onPressed: () {
                                _sendText(_textCtrl.text);
                                _textCtrl.clear();
                              },
                            ),
                          ],
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: tokens.border.withValues(alpha: 0.45),
                          ),
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: tokens.accent, width: 1.5),
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                      ),
                      onSubmitted: (value) {
                        _sendText(value);
                        _textCtrl.clear();
                      },
                    ),
                    const SizedBox(height: DS.s20),
                    AppActionGrid(
                      padding: EdgeInsets.zero,
                      minTileWidth: 84,
                      maxColumns: 3,
                      children: [
                        for (final action in _navigationActions)
                          AppActionCard(
                            label: action.label,
                            icon: action.icon,
                            onTap: () => _sendNav(action.command),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

const _navigationActions = <({
  IconData icon,
  String label,
  String command,
})>[
  (icon: LucideIcons.chevronLeft, label: 'Back', command: 'back'),
  (icon: LucideIcons.chevronUp, label: 'Up', command: 'up'),
  (icon: LucideIcons.home, label: 'Home', command: 'home'),
  (icon: LucideIcons.chevronLeft, label: 'Left', command: 'left'),
  (icon: LucideIcons.circle, label: 'Enter', command: 'enter'),
  (icon: LucideIcons.chevronRight, label: 'Right', command: 'right'),
  (icon: LucideIcons.info, label: 'Info', command: 'info'),
  (icon: LucideIcons.chevronDown, label: 'Down', command: 'down'),
  (icon: LucideIcons.menu, label: 'Menu', command: 'menu'),
];

