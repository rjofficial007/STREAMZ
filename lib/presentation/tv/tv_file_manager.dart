// presentation/tv/tv_file_manager.dart
// ============================================================================
// STREAMZ — TV & Desktop File Manager (Universal Resolution Support)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/models/media_item.dart';
import '../client/client_viewmodel.dart';
import '../player/player_screen.dart';
import '../shared/file_item.dart';

class TVFileManagerScreen extends StatefulWidget {
  const TVFileManagerScreen({super.key});

  @override
  State<TVFileManagerScreen> createState() => _TVFileManagerScreenState();
}

class _TVFileManagerScreenState extends State<TVFileManagerScreen> {
  final List<String?> _navStack = [null];
  String? get _currentPath => _navStack.last;

  List<SFileItem> _items = [];
  List<SFileItem> _allItems = [];
  bool _isLoading = true;
  String? _error;

  String _searchQuery = '';
  String _activeCategory = 'root';

  final _scrollCtrl = ScrollController();
  final _searchFocusNode = FocusNode();

  List<SFileItem> _activePlaylist = [];
  int _activePlayIndex = -1;

  String get _title {
    if (_activeCategory != 'root') return _activeCategory.toUpperCase();
    if (_currentPath == null || _currentPath!.isEmpty) return 'ROOT DIRECTORY';
    final parts = _currentPath!.replaceAll('\\', '/').split('/');
    return parts.where((s) => s.isNotEmpty).lastOrNull ?? _currentPath!.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHome();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadHome() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final media = context.read<ClientViewModel>().remoteMedia;
      _allItems = media.map((m) => SFileItem(name: m.title, path: m.id, isDirectory: false, size: 0, type: _parseType(m.type), isPathBased: false)).toList();
      await _loadPath('');
    } catch (_) {
      await _loadPath('');
    }
  }

  SFileType _parseType(String? t) {
    switch (t) {
      case 'video':
        return SFileType.video;
      case 'audio':
        return SFileType.audio;
      case 'image':
        return SFileType.image;
      default:
        return SFileType.other;
    }
  }

  Future<void> _loadPath(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _searchQuery = '';
    });
    try {
      final raw = await context.read<ClientViewModel>().browseRemote(path);
      final items = raw.map((e) => SFileItem.fromJson(e)).toList()
        ..sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'CONNECTION FAILED';
          _isLoading = false;
        });
      }
    }
  }

  void _switchCategory(String cat, SFileType? filter) {
    setState(() {
      _activeCategory = cat;
      _searchQuery = '';
    });
    if (cat == 'root') {
      _navStack.clear();
      _navStack.add('');
      _loadPath('');
    } else {
      setState(() {
        _items = filter != null ? _allItems.where((i) => i.type == filter).toList() : (cat == 'recent' ? _allItems.take(50).toList() : []);
        _isLoading = false;
      });
    }
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  void _navigateTo(String path) {
    setState(() => _activeCategory = 'root');
    _navStack.add(path);
    _loadPath(path);
  }

  bool _goBack() {
    if (_navStack.length > 1 && _activeCategory == 'root') {
      _navStack.removeLast();
      _loadPath(_navStack.last ?? '');
      return true;
    }
    return false;
  }

  void _openItem(SFileItem item) {
    if (item.isDirectory) {
      _navigateTo(item.path);
      return;
    }
    if (item.isPlayable) {
      final playable = _items.where((i) => i.isPlayable).toList();
      final idx = playable.indexWhere((i) => i.path == item.path);
      setState(() {
        _activePlaylist = playable.isEmpty ? [item] : playable;
        _activePlayIndex = idx >= 0 ? idx : 0;
      });
    } else {
      _showOptionsModal(item);
    }
  }

  void _triggerDownload(SFileItem item) {
    final mediaItem = MediaItem(id: item.path, title: item.name, duration: 0, type: item.mediaType, folder: 'Download');
    context.read<ClientViewModel>().downloadMedia(item: mediaItem, isPathBased: item.isPathBased);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'DOWNLOADING ${item.name.toUpperCase()}',
          style: const TextStyle(fontFamily: 'DM Mono', color: Colors.black, fontSize: 12),
        ),
        backgroundColor: DS.accent,
        duration: const Duration(seconds: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  void _showOptionsModal(SFileItem item) {
    final size = MediaQuery.sizeOf(context);
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      pageBuilder: (ctx, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: (size.width * 0.3).clamp(380.0, 500.0),
            decoration: BoxDecoration(
              color: DS.surface1,
              border: Border.all(color: DS.borderDefault, width: 2),
              boxShadow: const [BoxShadow(color: DS.accent, offset: Offset(8, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(DS.s24),
                  color: DS.surface2,
                  child: Text(item.name.toUpperCase(), style: AppTheme.theme.textTheme.titleMedium?.copyWith(fontSize: 18), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (item.isPlayable)
                  _TVModalBtn(
                    label: 'PLAY / VIEW',
                    autoFocus: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openItem(item);
                    },
                  ),
                if (!item.isDirectory)
                  _TVModalBtn(
                    label: 'DOWNLOAD FILE',
                    autoFocus: !item.isPlayable,
                    onTap: () {
                      Navigator.pop(ctx);
                      _triggerDownload(item);
                    },
                  ),
                _TVModalBtn(label: 'CANCEL', isDestructive: true, onTap: () => Navigator.pop(ctx)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<SFileItem> get _displayItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_activePlayIndex >= 0) {
            setState(() {
              _activePlaylist = [];
              _activePlayIndex = -1;
            });
          } else if (!_goBack()) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: DS.bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final sidebarW = (constraints.maxWidth * 0.18).clamp(200.0, 320.0);

              return Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSidebar(sidebarW, size),
                      Expanded(
                        child: FocusTraversalGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(constraints, size),
                              Expanded(child: _buildContent(size)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_activePlayIndex >= 0 && _activePlaylist.isNotEmpty)
                    _TVInlinePlayer(
                      playlist: _activePlaylist,
                      startIndex: _activePlayIndex,
                      vm: context.read<ClientViewModel>(),
                      onClose: () => setState(() {
                        _activePlaylist = [];
                        _activePlayIndex = -1;
                      }),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────

  Widget _buildSidebar(double width, Size size) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: DS.surface1,
        border: Border(right: BorderSide(color: DS.borderDefault)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(width * 0.1, (size.height * 0.05).clamp(20.0, 40.0), 16, 24),
            child: Text(
              'STREAMZ',
              style: AppTheme.theme.textTheme.titleMedium?.copyWith(color: DS.accent, fontSize: (size.width * 0.015).clamp(14.0, 22.0), fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1, color: DS.borderDefault),
          const SizedBox(height: 8),
          _TVSidebarBtn(icon: LucideIcons.hardDrive, label: 'ROOT FS', isActive: _activeCategory == 'root', autoFocus: true, onTap: () => _switchCategory('root', null)),
          _TVSidebarBtn(icon: LucideIcons.history, label: 'RECENT', isActive: _activeCategory == 'recent', onTap: () => _switchCategory('recent', null)),
          _TVSidebarBtn(icon: LucideIcons.film, label: 'VIDEOS', isActive: _activeCategory == 'video', onTap: () => _switchCategory('video', SFileType.video)),
          _TVSidebarBtn(icon: LucideIcons.music, label: 'AUDIO', isActive: _activeCategory == 'audio', onTap: () => _switchCategory('audio', SFileType.audio)),
          _TVSidebarBtn(icon: LucideIcons.image, label: 'IMAGES', isActive: _activeCategory == 'image', onTap: () => _switchCategory('image', SFileType.image)),
          const Spacer(),
          const Divider(height: 1, color: DS.borderDefault),
          Padding(
            padding: const EdgeInsets.all(DS.s16),
            child: Actions(
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
                child: AppButton(label: 'EXIT', icon: LucideIcons.arrowLeft, isPrimary: false, height: (size.height * 0.06).clamp(40.0, 60.0), onTap: () => Navigator.pop(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BoxConstraints constraints, Size size) {
    final titleFs = (constraints.maxWidth * 0.03).clamp(20.0, 48.0);
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s32, (size.height * 0.04).clamp(16.0, 40.0), DS.s32, 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DS.borderDefault)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIRECTORY',
                  style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.accent, fontSize: (size.width * 0.008).clamp(10.0, 14.0)),
                ),
                const SizedBox(height: 4),
                Text(
                  _title,
                  style: AppTheme.theme.textTheme.displayMedium?.copyWith(fontSize: titleFs, height: 1.0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: (constraints.maxWidth * 0.25).clamp(200.0, 400.0),
            child: TextField(
              focusNode: _searchFocusNode,
              style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: (size.width * 0.01).clamp(12.0, 18.0)),
              decoration: const InputDecoration(
                hintText: 'SEARCH...',
                hintStyle: TextStyle(color: DS.textMuted),
                filled: true,
                fillColor: DS.surface1,
                prefixIcon: Icon(LucideIcons.search, color: DS.textMuted, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: DS.borderDefault),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: DS.accent, width: 2),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ],
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(Size size) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: DS.accent, strokeWidth: 3));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.messageCircleWarning, size: 64, color: DS.textMuted),
            const SizedBox(height: 16),
            Text(_error!, style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              child: AppButton(label: 'RETRY', height: 50, onTap: () => _currentPath != null ? _loadPath(_currentPath!) : _loadHome()),
            ),
          ],
        ),
      );
    }

    final filtered = _displayItems;
    if (filtered.isEmpty) return Center(child: Text('NO ITEMS FOUND', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 16)));

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cardExtent = (constraints.maxWidth * 0.12).clamp(140.0, 220.0);
        return GridView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 100),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: cardExtent, childAspectRatio: 1.0, crossAxisSpacing: 16, mainAxisSpacing: 16),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _TVGridCard(item: filtered[i], vm: context.read<ClientViewModel>(), onTap: () => _openItem(filtered[i]), onLongPress: () => _showOptionsModal(filtered[i])),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE TV PLAYER (Logic Guard)
// ─────────────────────────────────────────────────────────────────────────────

class _TVInlinePlayer extends StatefulWidget {
  final List<SFileItem> playlist;
  final int startIndex;
  final ClientViewModel vm;
  final VoidCallback onClose;

  const _TVInlinePlayer({required this.playlist, required this.startIndex, required this.vm, required this.onClose});

  @override
  State<_TVInlinePlayer> createState() => _TVInlinePlayerState();
}

class _TVInlinePlayerState extends State<_TVInlinePlayer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFullPlayer());
  }

  void _openFullPlayer() {
    final mediaItems = widget.playlist.map((f) => MediaItem(id: f.path, title: f.name, duration: 0, type: f.mediaType, folder: 'TV')).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(items: mediaItems, startIndex: widget.startIndex, isPathBased: widget.playlist[widget.startIndex].isPathBased),
      ),
    ).then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// TV GRID CARD (D-Pad Optimized)
// ─────────────────────────────────────────────────────────────────────────────

class _TVGridCard extends StatefulWidget {
  final SFileItem item;
  final ClientViewModel vm;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TVGridCard({required this.item, required this.vm, required this.onTap, required this.onLongPress});

  @override
  State<_TVGridCard> createState() => _TVGridCardState();
}

class _TVGridCardState extends State<_TVGridCard> {
  bool _focused = false;

  KeyEventResult _handleCardKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Support for hardware "Menu" or "Context Menu" buttons (Kodi-style)
    if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
      widget.onLongPress();
      return KeyEventResult.handled;
    }

    return handleTVSelectKey(event, widget.onTap);
  }

  @override
  Widget build(BuildContext context) {
    String? thumbUrl;
    if (widget.item.isPlayable) {
      thumbUrl = widget.item.isPathBased
          ? (widget.item.type == SFileType.image ? widget.vm.fileUrl(widget.item.path) : widget.vm.thumbnailUrlForPath(widget.item.path))
          : widget.vm.thumbnailUrl(widget.item.path);
    }

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
          setState(() => _focused = v);
          if (v) handleTVFocusScroll(v, context);
        },
        onKeyEvent: _handleCardKey,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: _focused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: DS.surface1,
                border: Border.all(color: _focused ? DS.accent : DS.borderDefault, width: _focused ? 3 : 1),
                boxShadow: _focused ? [BoxShadow(color: DS.accent.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 2)] : [],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.item.isDirectory)
                    Center(child: Icon(LucideIcons.folder, size: 56, color: _focused ? DS.accent : DS.textPrimary))
                  else if (thumbUrl != null)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _focused ? 1.0 : 0.7,
                      child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.icon),
                    )
                  else
                    Center(child: Icon(widget.item.icon, size: 48, color: DS.textMuted)),

                  Positioned(
                    top: DS.s8,
                    left: DS.s8,
                    child: StatusBadge(label: widget.item.isDirectory ? '${widget.item.itemCount} ITEMS' : widget.item.typeLabel),
                  ),
                  if (widget.item.type == SFileType.video)
                    Positioned(
                      bottom: 36,
                      right: DS.s8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: DS.accent,
                        child: const Icon(LucideIcons.play, color: Colors.black, size: 14),
                      ),
                    ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      color: _focused ? DS.accent : Colors.black87,
                      child: Text(
                        widget.item.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: _focused ? Colors.black : Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV SIDEBAR BUTTON (Scaling)
// ─────────────────────────────────────────────────────────────────────────────

class _TVSidebarBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool autoFocus;

  const _TVSidebarBtn({required this.icon, required this.label, required this.isActive, required this.onTap, this.autoFocus = false});

  @override
  State<_TVSidebarBtn> createState() => _TVSidebarBtnState();
}

class _TVSidebarBtnState extends State<_TVSidebarBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.isActive;
    final size = MediaQuery.sizeOf(context);

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
        autofocus: widget.autoFocus,
        onFocusChange: (v) {
          setState(() => _focused = v);
          if (v) handleTVFocusScroll(v, context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: DS.s24, vertical: (size.height * 0.02).clamp(12.0, 20.0)),
            decoration: BoxDecoration(
              color: _focused ? DS.accent : (widget.isActive ? DS.surface3 : Colors.transparent),
              border: Border(left: BorderSide(color: active ? DS.accent : Colors.transparent, width: 4)),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: (size.width * 0.012).clamp(18.0, 24.0), color: _focused ? Colors.black : (active ? Colors.white : DS.textMuted)),
                const SizedBox(width: 16),
                Text(
                  widget.label,
                  style: AppTheme.theme.textTheme.labelMedium?.copyWith(
                    fontSize: (size.width * 0.01).clamp(12.0, 18.0),
                    fontWeight: FontWeight.bold,
                    color: _focused ? Colors.black : (active ? Colors.white : DS.textMuted),
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

// ─────────────────────────────────────────────────────────────────────────────
// TV MODAL BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _TVModalBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool autoFocus;
  final bool isDestructive;

  const _TVModalBtn({required this.label, required this.onTap, this.autoFocus = false, this.isDestructive = false});

  @override
  State<_TVModalBtn> createState() => _TVModalBtnState();
}

class _TVModalBtnState extends State<_TVModalBtn> {
  bool _focused = false;

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
        autofocus: widget.autoFocus,
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: DS.s24, vertical: 20),
            decoration: BoxDecoration(
              color: _focused ? (widget.isDestructive ? Colors.redAccent : DS.accent) : Colors.transparent,
              border: const Border(bottom: BorderSide(color: DS.borderDefault)),
            ),
            child: Text(
              widget.label,
              style: AppTheme.theme.textTheme.labelMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _focused ? Colors.black : (widget.isDestructive ? Colors.redAccent : Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
