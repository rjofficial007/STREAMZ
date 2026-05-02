// presentation/mobile/downloads_sheet.dart
// ============================================================================
// STREAMZ — Downloads Bottom Sheet + Screen
// ============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/models/download_task.dart';
import '../../domain/services/download_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHOW HELPER
// ─────────────────────────────────────────────────────────────────────────────

void showDownloadsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: DS.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => ChangeNotifierProvider.value(value: context.read<DownloadService>(), child: const _DownloadsSheet()),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadsSheet extends StatefulWidget {
  const _DownloadsSheet();

  @override
  State<_DownloadsSheet> createState() => _DownloadsSheetState();
}

class _DownloadsSheetState extends State<_DownloadsSheet> {
  String _activeFilter = 'All';
  final _filters = ['All', 'Video', 'Audio', 'Image'];

  int _totalBytes = 64 * 1024 * 1024 * 1024;
  int _freeBytes = 22 * 1024 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _fetchStorage();
  }

  Future<void> _fetchStorage() async {
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final res = await Process.run('wmic', ['logicaldisk', 'where', 'DeviceID="C:"', 'get', 'FreeSpace,Size', '/Value']);
        int free = 0, total = 0;
        for (final line in res.stdout.toString().split('\n')) {
          if (line.trim().startsWith('FreeSpace=')) {
            free = int.tryParse(line.split('=')[1].trim()) ?? 0;
          }
          if (line.trim().startsWith('Size=')) {
            total = int.tryParse(line.split('=')[1].trim()) ?? 0;
          }
        }
        if (total > 0 && mounted) {
          setState(() {
            _totalBytes = total;
            _freeBytes = free;
          });
        }
      } else {
        final path = defaultTargetPlatform == TargetPlatform.android ? '/storage/emulated/0' : '/';
        final res = await Process.run('df', ['-k', path]);
        final lines = res.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].trim().split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final totalK = int.tryParse(parts[1]) ?? 0;
            final freeK = int.tryParse(parts[3]) ?? 0;
            if (totalK > 0 && mounted) {
              setState(() {
                _totalBytes = totalK * 1024;
                _freeBytes = freeK * 1024;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Storage fetch error: $e');
    }
  }

  void _confirmDelete(BuildContext ctx, DownloadTask task) {
    showDialog(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: DS.surface1,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: DS.borderDefault),
          borderRadius: BorderRadius.zero,
        ),
        title: Text('DELETE FILE', style: AppTheme.theme.textTheme.titleMedium?.copyWith(fontSize: 18)),
        content: Text("CONFIRM REMOVAL OF '${task.title.toUpperCase()}'?", style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('CANCEL', style: AppTheme.theme.textTheme.labelSmall),
          ),
          TextButton(
            onPressed: () {
              context.read<DownloadService>().delete(task);
              Navigator.pop(dlgCtx);
            },
            child: Text('DELETE', style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DownloadService>();
    final all = svc.tasks;
    final filtered = _activeFilter == 'All' ? all : all.where((d) => d.type.toLowerCase() == _activeFilter.toLowerCase()).toList();
    final active = filtered.where((d) => d.isActive).toList();
    final completed = filtered.where((d) => d.isCompleted).toList();

    final totalGB = _totalBytes / (1024 * 1024 * 1024);
    final freeGB = _freeBytes / (1024 * 1024 * 1024);
    final usedGB = totalGB - freeGB;
    final progress = totalGB > 0 ? usedGB / totalGB : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: DS.bg,
          border: Border(top: BorderSide(color: DS.borderDefault, width: 1)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: DS.s24, vertical: DS.s16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DS.borderDefault)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(PhosphorIconsFill.downloadSimple, color: DS.accent, size: 20),
                      const SizedBox(width: DS.s12),
                      Text('DOWNLOAD CENTER', style: AppTheme.theme.textTheme.titleMedium?.copyWith(fontSize: 18, letterSpacing: 1.0)),
                    ],
                  ),
                  Row(
                    children: [
                      if (completed.isNotEmpty)
                        Actions(
                          actions: {
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) {
                                context.read<DownloadService>().clearCompleted();
                                return null;
                              },
                            ),
                          },
                          child: Focus(
                            child: TextButton(
                              onPressed: () => context.read<DownloadService>().clearCompleted(),
                              child: Text('CLEAR DONE', style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.textMuted, fontSize: 10)),
                            ),
                          ),
                        ),
                      Actions(
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (_) {
                              Navigator.pop(context);
                              return null;
                            },
                          ),
                        },
                        child: Focus(
                          onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => Navigator.pop(context)),
                          child: IconButton(
                            icon: const Icon(PhosphorIconsRegular.x, color: Colors.white, size: 24),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(DS.s24, DS.s24, DS.s24, 60),
                children: [
                  // Storage card
                  BrutalistBlock(
                    padding: const EdgeInsets.all(DS.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('STORAGE ALLOCATION', style: AppTheme.theme.textTheme.labelSmall),
                        const SizedBox(height: DS.s12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${usedGB.toStringAsFixed(1)} GB', style: AppTheme.theme.textTheme.headlineSmall?.copyWith(fontSize: 32, height: 1.0)),
                            const SizedBox(width: DS.s8),
                            Text('OF ${totalGB.toStringAsFixed(1)} GB', style: AppTheme.theme.textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: DS.s16),
                        LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: DS.surface1, valueColor: const AlwaysStoppedAnimation(DS.accent), minHeight: 4),
                        const SizedBox(height: DS.s8),
                        Text('${freeGB.toStringAsFixed(1)} GB AVAILABLE', style: AppTheme.theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: DS.s24),

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters
                          .map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(right: DS.s8),
                              child: _FilterChip(label: f, isActive: _activeFilter == f, onTap: () => setState(() => _activeFilter = f)),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: DS.s24),

                  // Active transfers
                  if (active.isNotEmpty) ...[
                    Text('ACTIVE TRANSFERS', style: AppTheme.theme.textTheme.labelSmall),
                    const SizedBox(height: DS.s8),
                    ...active.map((t) => _ActiveCard(task: t, onDelete: () => _confirmDelete(context, t))),
                    const SizedBox(height: DS.s24),
                  ],

                  // Completed
                  if (completed.isNotEmpty) ...[
                    Text('ARCHIVED', style: AppTheme.theme.textTheme.labelSmall),
                    const SizedBox(height: DS.s8),
                    ...completed.map((t) => _CompletedCard(task: t, onDelete: () => _confirmDelete(context, t))),
                  ],

                  // Empty
                  if (all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(PhosphorIconsRegular.cloudArrowDown, size: 48, color: DS.borderDefault),
                            const SizedBox(height: DS.s16),
                            Text('NO DOWNLOADS FOUND', style: AppTheme.theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP (Keyboard & TV Compliant)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isActive, required this.onTap});

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
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
        onFocusChange: (v) {
          setState(() => _isFocused = v);
          handleTVFocusScroll(v, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s8),
            decoration: BoxDecoration(
              color: widget.isActive ? DS.accent : (_isFocused ? DS.surface3 : Colors.transparent),
              border: Border.all(color: widget.isActive ? DS.accent : (_isFocused ? DS.accent : DS.borderDefault), width: _isFocused ? 2 : 1),
            ),
            child: Text(
              widget.label.toUpperCase(),
              style: GoogleFonts.dmMono(color: widget.isActive ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE DOWNLOAD CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onDelete;

  const _ActiveCard({required this.task, required this.onDelete});

  IconData get _icon {
    if (task.type == 'video') return PhosphorIconsFill.filmStrip;
    if (task.type == 'audio') return PhosphorIconsFill.musicNote;
    if (task.type == 'image') return PhosphorIconsFill.image;
    return PhosphorIconsFill.file;
  }

  @override
  Widget build(BuildContext context) {
    return BrutalistBlock(
      padding: const EdgeInsets.all(DS.s12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_icon, color: DS.accent, size: 20),
              const SizedBox(width: DS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title.toUpperCase(), style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<double>(
                      valueListenable: task.progressNotifier,
                      builder: (_, prog, _) => Text(
                        '${(prog * task.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB'
                        ' / ${(task.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
              Actions(
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      onDelete();
                      return null;
                    },
                  ),
                },
                child: Focus(
                  onKeyEvent: (_, ev) => handleTVSelectKey(ev, onDelete),
                  child: IconButton(
                    icon: const Icon(PhosphorIconsRegular.x, color: Colors.white54, size: 16),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s12),
          ValueListenableBuilder<double>(
            valueListenable: task.progressNotifier,
            builder: (_, prog, _) => LinearProgressIndicator(value: prog.clamp(0.0, 1.0), backgroundColor: DS.surface1, valueColor: const AlwaysStoppedAnimation(DS.accent), minHeight: 2),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETED CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onDelete;

  const _CompletedCard({required this.task, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: DS.surface1,
        border: Border.all(color: DS.borderDefault),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: 0),
        leading: const Icon(PhosphorIconsFill.check, color: DS.accent, size: 18),
        title: Text(task.title.toUpperCase(), style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${task.type.toUpperCase()} // '
          '${(task.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
          style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 9),
        ),
        trailing: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onDelete();
                return null;
              },
            ),
          },
          child: Focus(
            onKeyEvent: (_, ev) => handleTVSelectKey(ev, onDelete),
            child: IconButton(
              icon: const Icon(PhosphorIconsFill.trash, color: Colors.white54, size: 16),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ),
    );
  }
}
