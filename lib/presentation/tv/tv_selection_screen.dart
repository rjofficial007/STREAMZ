// presentation/tv/tv_selection_screen.dart
// ============================================================================
// STREAMZ — TV Interface Selection Gateway
// ============================================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../client/client_viewmodel.dart';
import 'tv_file_manager.dart';
import 'tv_home_screen.dart';

class TVSelectionScreen extends StatelessWidget {
  const TVSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: DS.bg,
        leading: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
              context.read<ClientViewModel>().disconnect();
              Navigator.pop(context);
              return null;
            }),
          },
          child: Focus(
            onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
              context.read<ClientViewModel>().disconnect();
              Navigator.pop(context);
            }),
            child: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 24, color: DS.textPrimary),
              onPressed: () {
                context.read<ClientViewModel>().disconnect();
                Navigator.pop(context);
              },
            ),
          ),
        ),
        title: Text(
          'SELECT INTERFACE',
          style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(opacity: 0.12, child: const CustomPaint(painter: GridPainter())),
          ),
          SafeArea(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SelectionCard(
                    title: 'MODERN UI',
                    subtitle: 'NETFLIX-STYLE RAILS',
                    icon: PhosphorIconsRegular.television,
                    autoFocus: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: context.read<ClientViewModel>(),
                          child: const TVHomeScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s48),
                  _SelectionCard(
                    title: 'FILE SYSTEM',
                    subtitle: 'RAW DIRECTORY ACCESS',
                    icon: PhosphorIconsRegular.folderOpen,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: context.read<ClientViewModel>(),
                          child: const TVFileManagerScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool autoFocus;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.autoFocus = false,
  });

  @override
  State<_SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends State<_SelectionCard> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _focused || _pressed;
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: Focus(
        autofocus: widget.autoFocus,
        onFocusChange: (v) {
          setState(() => _focused = v);
          handleTVFocusScroll(v, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              color: isActive ? DS.accent : DS.surface1,
              border: Border.all(color: isActive ? DS.accent : DS.borderDefault, width: isActive ? 4 : 1),
              boxShadow: isActive ? [const BoxShadow(color: DS.accent, blurRadius: 20, offset: Offset(0, 10))] : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 72, color: isActive ? DS.bg : DS.textPrimary),
                const SizedBox(height: DS.s32),
                Text(
                  widget.title,
                  style: AppTheme.theme.textTheme.displayMedium?.copyWith(
                    color: isActive ? DS.bg : DS.textPrimary,
                    fontSize: 36,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: DS.s8),
                Text(
                  widget.subtitle,
                  style: AppTheme.theme.textTheme.labelMedium?.copyWith(
                    color: isActive ? DS.bg : DS.textMuted,
                    letterSpacing: 2,
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