// presentation/mobile/mobile_selection_screen.dart
// ============================================================================
// STREAMZ — Mobile Interface Selection Gateway
// ============================================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../client/client_viewmodel.dart';
import 'file_manager.dart';
import 'modern_mobile_ui.dart';

class MobileSelectionScreen extends StatelessWidget {
  const MobileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: DS.bg,
        leading: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                context.read<ClientViewModel>().disconnect();
                Navigator.pop(context);
                return null;
              },
            ),
          },
          child: Focus(
            onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
              context.read<ClientViewModel>().disconnect();
              Navigator.pop(context);
            }),
            child: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 20, color: DS.textPrimary),
              onPressed: () {
                context.read<ClientViewModel>().disconnect();
                Navigator.pop(context);
              },
            ),
          ),
        ),
        title: Text('SELECT INTERFACE', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(opacity: 0.12, child: const CustomPaint(painter: GridPainter())),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(DS.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MobileSelectionCard(
                      title: 'MODERN UI',
                      subtitle: 'NETFLIX-STYLE RAILS',
                      icon: PhosphorIconsRegular.television,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(value: context.read<ClientViewModel>(), child: const ModernMobileUIScreen()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DS.s24),
                  Expanded(
                    child: _MobileSelectionCard(
                      title: 'FILE SYSTEM',
                      subtitle: 'RAW DIRECTORY ACCESS',
                      icon: PhosphorIconsRegular.folderOpen,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(value: context.read<ClientViewModel>(), child: const SamsungFileManagerScreen()),
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

class _MobileSelectionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MobileSelectionCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  State<_MobileSelectionCard> createState() => _MobileSelectionCardState();
}

class _MobileSelectionCardState extends State<_MobileSelectionCard> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _pressed || _focused;
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: isActive ? DS.surface3 : DS.surface1,
              border: Border.all(color: isActive ? DS.accent : DS.borderDefault, width: isActive ? 2 : 1),
              boxShadow: isActive ? [const BoxShadow(color: DS.accent, offset: Offset(4, 4))] : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 48, color: isActive ? DS.accent : DS.textPrimary),
                const SizedBox(height: DS.s24),
                Text(widget.title, style: AppTheme.theme.textTheme.displayMedium?.copyWith(color: DS.textPrimary, fontSize: 32, height: 1.0)),
                const SizedBox(height: DS.s8),
                Text(widget.subtitle, style: AppTheme.theme.textTheme.labelMedium?.copyWith(color: DS.textMuted, fontSize: 10, letterSpacing: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
