// presentation/mobile/downloads_sheet.dart
// ============================================================================
// STREAMZ — Downloads Bottom Sheet + Screen
// ============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/download_task.dart';
import 'package:streamz/domain/services/download_service.dart';
import 'package:streamz/presentation/shared/app_bottom_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHOW HELPER
// ─────────────────────────────────────────────────────────────────────────────

void showDownloadsSheet(BuildContext context) {
  showAppBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<DownloadService>(),
      child: const _DownloadsSheet(),
    ),
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

  int? _totalBytes;
  int? _freeBytes;

  @override
  void initState() {
    super.initState();
    _fetchStorage();
  }

  Future<void> _fetchStorage() async {
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final res = await Process.run('wmic', [
          'logicaldisk',
          'where',
          'DeviceID="C:"',
          'get',
          'FreeSpace,Size',
          '/Value',
        ]);
        var free = 0;
        var total = 0;
        for (final line in res.stdout.toString().split('\n')) {
          if (line.trim().startsWith('FreeSpace=')) {
            free = int.tryParse(line.split('=')[1].trim()) ?? 0;
          }
          if (line.trim().startsWith('Size=')) {
            total = int.tryParse(line.split('=')[1].trim()) ?? 0;
          }
        }
        if (res.exitCode == 0 && total > 0 && free >= 0 && mounted) {
          setState(() {
            _totalBytes = total;
            _freeBytes = free;
          });
        }
      } else {
        final path = defaultTargetPlatform == TargetPlatform.android
            ? '/storage/emulated/0'
            : '/';
        final res = await Process.run('df', ['-k', path]);
        final lines = res.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].trim().split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final totalK = int.tryParse(parts[1]) ?? 0;
            final freeK = int.tryParse(parts[3]) ?? 0;
            if (res.exitCode == 0 && totalK > 0 && freeK >= 0 && mounted) {
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
    final tokens = ctx.tokens;
    showDialog(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: tokens.surface1,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(DS.radius(12)),
        ),
        title: Text(
          'DELETE FILE',
          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontSize: 18),
        ),
        content: Text(
          "CONFIRM REMOVAL OF '${task.title.toUpperCase()}'?",
          style: Theme.of(ctx).textTheme.labelMedium?.copyWith(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('CANCEL', style: Theme.of(ctx).textTheme.labelSmall),
          ),
          TextButton(
            onPressed: () {
              ctx.read<DownloadService>().delete(task);
              context.pop();
            },
            child: Text(
              'DELETE',
              style: Theme.of(
                ctx,
              ).textTheme.labelSmall?.copyWith(color: tokens.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final svc = context.watch<DownloadService>();
    final all = svc.tasks;
    final filtered = _activeFilter == 'All'
        ? all
        : all
              .where((d) => d.type.toLowerCase() == _activeFilter.toLowerCase())
              .toList();
    final active = filtered.where((d) => d.isActive).toList();
    final completed = filtered.where((d) => d.isCompleted).toList();

    final totalGB = _totalBytes == null
        ? null
        : _totalBytes! / (1024 * 1024 * 1024);
    final freeGB = _freeBytes == null
        ? null
        : _freeBytes! / (1024 * 1024 * 1024);
    final usedGB = totalGB == null || freeGB == null
        ? null
        : (totalGB - freeGB).clamp(0.0, totalGB);
    final progress = totalGB == null || usedGB == null || totalGB == 0
        ? null
        : usedGB / totalGB;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => ColoredBox(
        color: tokens.surface1,
        child: Column(
          children: [
            AppSheetHeader(
              title: 'Download center',
              subtitle: 'Manage active transfers and saved files',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (completed.isNotEmpty)
                    TextButton(
                      onPressed: () => context
                          .read<DownloadService>()
                          .clearCompleted(),
                      child: Text(
                        'CLEAR DONE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Close download center',
                    icon: Icon(
                      LucideIcons.x,
                      color: tokens.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                  DS.s16,
                  0,
                  DS.s16,
                  DS.s48,
                ),
                children: [
                  // Storage card
                  AppPanel(
                    padding: const EdgeInsets.all(DS.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STORAGE ALLOCATION',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: DS.s12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              usedGB == null
                                  ? 'Storage unavailable'
                                  : '${usedGB.toStringAsFixed(1)} GB',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontSize: usedGB == null ? 18 : 32,
                                    height: 1.0,
                                  ),
                            ),
                            const SizedBox(width: DS.s8),
                            Text(
                              totalGB == null
                                  ? ''
                                  : 'OF ${totalGB.toStringAsFixed(1)} GB',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: DS.s16),
                        if (progress != null) ...[
                          LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: tokens.surface2,
                            valueColor: AlwaysStoppedAnimation(tokens.accent),
                            minHeight: 4,
                          ),
                          const SizedBox(height: DS.s8),
                          Text(
                            '${freeGB!.toStringAsFixed(1)} GB AVAILABLE',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
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
                              child: _FilterChip(
                                label: f,
                                isActive: _activeFilter == f,
                                onTap: () => setState(() => _activeFilter = f),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: DS.s24),

                  // Active transfers
                  if (active.isNotEmpty) ...[
                    Text(
                      'ACTIVE TRANSFERS',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: DS.s8),
                    ...active.map(
                      (t) => _ActiveCard(
                        task: t,
                        onDelete: () => _confirmDelete(context, t),
                      ),
                    ),
                    const SizedBox(height: DS.s24),
                  ],

                  // Completed
                  if (completed.isNotEmpty) ...[
                    Text(
                      'ARCHIVED',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: DS.s8),
                    ...completed.map(
                      (t) => _CompletedCard(
                        task: t,
                        onDelete: () => _confirmDelete(context, t),
                      ),
                    ),
                  ],

                  // Empty
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.download,
                              size: 48,
                              color: tokens.border.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: DS.s16),
                            Text(
                              all.isEmpty
                                  ? 'NO DOWNLOADS FOUND'
                                  : 'NO ${_activeFilter.toUpperCase()} DOWNLOADS',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
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
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
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
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s16,
              vertical: DS.s8,
            ),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? tokens.accent
                  : (_isFocused ? tokens.surface3 : Colors.transparent),
              borderRadius: BorderRadius.circular(DS.radiusLg),
              border: Border.all(
                color: widget.isActive
                    ? tokens.accent
                    : (_isFocused
                          ? tokens.accent
                          : tokens.border.withValues(alpha: 0.15)),
                width: _isFocused ? 2 : 1,
              ),
            ),
            child: Text(
              widget.label.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: widget.isActive ? tokens.background : tokens.textPrimary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
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
  const _ActiveCard({required this.task, required this.onDelete});
  final DownloadTask task;
  final VoidCallback onDelete;

  IconData get _icon {
    if (task.type == 'video') return LucideIcons.video;
    if (task.type == 'audio') return LucideIcons.music;
    if (task.type == 'image') return LucideIcons.image;
    return LucideIcons.file;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppPanel(
      padding: const EdgeInsets.all(DS.s12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_icon, color: tokens.accent, size: 20),
              const SizedBox(width: DS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title.toUpperCase(),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<double>(
                      valueListenable: task.progressNotifier,
                      builder: (_, prog, _) => Text(
                        '${(prog * task.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB'
                        ' / ${(task.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall,
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
                    icon: Icon(
                      LucideIcons.x,
                      color: tokens.textMuted,
                      size: 16,
                    ),
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
            builder: (_, prog, _) => LinearProgressIndicator(
              value: prog.clamp(0.0, 1.0),
              backgroundColor: tokens.surface2,
              valueColor: AlwaysStoppedAnimation(tokens.accent),
              minHeight: 2,
            ),
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
  const _CompletedCard({required this.task, required this.onDelete});
  final DownloadTask task;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: tokens.surface2.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: 0,
        ),
        leading: Icon(LucideIcons.check, color: tokens.accent, size: 18),
        title: Text(
          task.title.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${task.type.toUpperCase()} // '
          '${(task.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
          style: Theme.of(context).textTheme.labelSmall,
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
              icon: Icon(LucideIcons.trash, color: tokens.textMuted, size: 16),
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
