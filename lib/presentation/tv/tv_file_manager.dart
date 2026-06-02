// presentation/tv/tv_file_manager.dart
// ============================================================================
// STREAMZ — TV File Manager (Brutalist Web Studio Edition)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/media_item.dart';
import '../client/client_viewmodel.dart';
import 'tv_player_screen.dart';
import '../shared/file_item.dart';


class TVFileManagerScreen extends StatefulWidget {
  const TVFileManagerScreen({super.key});

  @override
  State<TVFileManagerScreen> createState() => _TVFileManagerScreenState();
}

class _TVFileManagerScreenState extends State<TVFileManagerScreen> {
  final List<String?> _navStack = [null];

  List<SFileItem> _items = [];
  List<SFileItem> _allItems = [];
  bool _isLoading = true;
  String? _error;

  String _searchQuery = '';
  String _activeCategory = 'video';

  List<Map<String, dynamic>> _stations = [];

  final _scrollCtrl = ScrollController();
  final _searchFocusNode = FocusNode();

  List<SFileItem> _activePlaylist = [];
  int _activePlayIndex = -1;

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
      final vm = context.read<ClientViewModel>();
      final media = vm.remoteMedia;
      _stations = vm.stations;
      _allItems = media.map((m) => SFileItem(name: m.title, path: m.id, isDirectory: false, size: 0, type: _parseType(m.type), isPathBased: false)).toList();
      _switchCategory('video', SFileType.video);
    } catch (_) {
      _switchCategory('video', SFileType.video);
    }
  }

  SFileType _parseType(String? t) {
    switch (t) {
      case 'video': return SFileType.video;
      case 'audio': return SFileType.audio;
      case 'image': return SFileType.image;
      default: return SFileType.other;
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
    if (cat == 'folder') {
      _navStack.clear();
      _navStack.add('');
      _loadPath('');
    } else if (cat == 'station') {
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _items = filter != null ? _allItems.where((i) => i.type == filter).toList() : [];
        _isLoading = false;
      });
    }
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  void _navigateTo(String path) {
    setState(() => _activeCategory = 'folder');
    _navStack.add(path);
    _loadPath(path);
  }

  bool _goBack() {
    if (_navStack.length > 1 && _activeCategory == 'folder') {
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

  void _tuneIn(Map<String, dynamic> station) async {
    final vm = context.read<ClientViewModel>();
    final res = await vm.joinStation(station['id']);
    if (res != null && mounted) {
      final items = (res['playlist'] as List?)?.map((e) => MediaItem.fromJson(e)).toList() ?? [MediaItem.fromJson(res['item'])];
      final startIndex = res['itemIndex'] as int? ?? 0;
      final offsetMs = res['positionMs'] as int;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TVPlayerScreen(
            items: items,
            startIndex: startIndex,
            isPathBased: false,
            startOffset: Duration(milliseconds: offsetMs),
          ),
        ),
      );
    }
  }

  void _triggerDownload(SFileItem item) {
    final tokens = context.tokens;
    final mediaItem = MediaItem(id: item.path, title: item.name, duration: 0, type: item.mediaType, folder: 'Download');
    context.read<ClientViewModel>().downloadMedia(item: mediaItem, isPathBased: item.isPathBased);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'CMD // DOWNLOADING ${item.name.toUpperCase()}',
          style: GoogleFonts.dmMono(color: tokens.background, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        backgroundColor: tokens.textPrimary,
        duration: const Duration(seconds: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  void _showOptionsModal(SFileItem item) {
    final size = MediaQuery.sizeOf(context);
    final tokens = context.tokens;
    showGeneralDialog(
      context: context,
      barrierColor: tokens.background.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      pageBuilder: (ctx, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: (size.width * 0.4).clamp(400.0, 600.0),
            decoration: BoxDecoration(
              color: tokens.surface1,
              border: Border.all(color: tokens.textPrimary, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                  child: Text(
                      item.name.toUpperCase(),
                      style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis
                  ),
                ),
                if (item.isPlayable)
                  _TVModalBtn(
                    label: 'PLAY / VIEW MEDIA',
                    autoFocus: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openItem(item);
                    },
                  ),
                if (!item.isDirectory)
                  _TVModalBtn(
                    label: 'DOWNLOAD TO LOCAL',
                    autoFocus: !item.isPlayable,
                    onTap: () {
                      Navigator.pop(ctx);
                      _triggerDownload(item);
                    },
                  ),
                _TVModalBtn(label: 'CANCEL OPERATION', isDestructive: true, onTap: () => Navigator.pop(ctx)),
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
    final isMobile = size.width < 768;
    final tokens = context.tokens;

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
        backgroundColor: tokens.background,
        body: Column(
          children: [
            _buildTopDashboard(context, size),
            Expanded(
              child: Stack(
                children: [
                  FocusTraversalGroup(
                    child: _buildContent(context, size),
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
              ),
            ),
            if (isMobile) _buildBottomNavbar(context, size),
          ],
        ),
      ),
    );
  }

  // ── Top Dashboard ────────────────────────────────────────────────────────

  Widget _buildTopDashboard(BuildContext context, Size size) {
    final isMobile = size.width < 768;
    final tokens = context.tokens;

    return Container(
      height: isMobile ? 56 : 72,
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(border: Border(right: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
              child: Actions(
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      if (!_goBack()) Navigator.pop(context);
                      return null;
                    },
                  ),
                },
                child: Focus(
                  onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
                    if (!_goBack()) Navigator.pop(context);
                  }),
                  child: IconButton(
                    icon: Icon(LucideIcons.chevronLeft, color: tokens.textPrimary, size: 24),
                    onPressed: () {
                      if (!_goBack()) Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(border: Border(right: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
              child: Row(
                children: [
                  Text('STREAMZ', style: GoogleFonts.barlowCondensed(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, color: tokens.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _TopNavBtn(label: 'VIDEOS', isActive: _activeCategory == 'video', onTap: () => _switchCategory('video', SFileType.video)),
                  _TopNavBtn(label: 'AUDIO', isActive: _activeCategory == 'audio', onTap: () => _switchCategory('audio', SFileType.audio)),
                  _TopNavBtn(label: 'PHOTOS', isActive: _activeCategory == 'image', onTap: () => _switchCategory('image', SFileType.image)),
                  _TopNavBtn(label: 'NETWORK', isActive: _activeCategory == 'folder', onTap: () => _switchCategory('folder', null)),
                  _TopNavBtn(label: 'STATIONS', isActive: _activeCategory == 'station', onTap: () => _switchCategory('station', null)),
                ],
              ),
            ),
          ],
          Container(
            width: isMobile ? size.width : 300,
            color: tokens.background,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _searchFocusNode,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, letterSpacing: 1),
                    decoration: InputDecoration(
                      hintText: 'SEARCH QUERY...',
                      hintStyle: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ── Bottom Navbar ─────────────────────────────────────────────────────────

  Widget _buildBottomNavbar(BuildContext context, Size size) {
    final tokens = context.tokens;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          _BottomNavBtn(label: 'VIDEOS', isActive: _activeCategory == 'video', onTap: () => _switchCategory('video', SFileType.video)),
          _BottomNavBtn(label: 'AUDIO', isActive: _activeCategory == 'audio', onTap: () => _switchCategory('audio', SFileType.audio)),
          _BottomNavBtn(label: 'PHOTOS', isActive: _activeCategory == 'image', onTap: () => _switchCategory('image', SFileType.image)),
          _BottomNavBtn(label: 'SYSTEM', isActive: _activeCategory == 'folder', onTap: () => _switchCategory('folder', null)),
          _BottomNavBtn(label: 'LIVE', isActive: _activeCategory == 'station', onTap: () => _switchCategory('station', null)),
        ],
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, Size size) {
    final tokens = context.tokens;
    if (_isLoading) return Center(child: CircularProgressIndicator(color: tokens.textPrimary, strokeWidth: 2));
    if (_error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
          decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15), style: BorderStyle.solid)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertTriangle, size: 64, color: tokens.textMuted),
              const SizedBox(height: 24),
              Text('SIGNAL ERROR // ${_error?.toUpperCase()}', style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 14, letterSpacing: 2)),
              const SizedBox(height: 32),
              _HardwareBtn(label: 'RETRY CONNECTION', width: 240, onTap: _loadHome),
            ],
          ),
        ),
      );
    }

    if (_activeCategory == 'station') {
      if (_stations.isEmpty) {
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
            decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15), style: BorderStyle.solid)),
            child: Text('NO ACTIVE BROADCASTS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 16, letterSpacing: 4)),
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(color: tokens.border.withValues(alpha: 0.15)),
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _TVStationCard(
                  station: _stations[i],
                  onTap: () => _tuneIn(_stations[i]),
                ),
                childCount: _stations.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      );
    }

    final filtered = _displayItems;
    if (filtered.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
          decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15), style: BorderStyle.solid)),
          child: Text('0 SIGNALS FOUND', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 16, letterSpacing: 4)),
        ),
      );
    }

    final width = size.width;
    int crossAxisCount = 6;
    if (width < 380) {
      crossAxisCount = 3;
    } else if (width < 768) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = (width ~/ 200).clamp(6, 12);
    }

    return Container(
      decoration: BoxDecoration(color: tokens.border.withValues(alpha: 0.15)),
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.0,
              crossAxisSpacing: 1,
              mainAxisSpacing: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _TVGridCard(item: filtered[i], vm: context.read<ClientViewModel>(), onTap: () => _openItem(filtered[i]), onLongPress: () => _showOptionsModal(filtered[i])),
              childCount: filtered.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
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
    final mediaItems = widget.playlist.map((f) => MediaItem(id: f.path, title: f.name, duration: 0, type: f.mediaType, folder: 'SYS')).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TVPlayerScreen(items: mediaItems, startIndex: widget.startIndex, isPathBased: widget.playlist[widget.startIndex].isPathBased),
      ),
    ).then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// TV GRID CARD (Brutalist 78/22 Split)
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

class _TVGridCardState extends State<_TVGridCard> with SingleTickerProviderStateMixin {
  bool _focused = false;
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  KeyEventResult _handleCardKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
      widget.onLongPress();
      return KeyEventResult.handled;
    }
    return handleTVSelectKey(event, widget.onTap);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    String? thumbUrl;
    if (widget.item.isPlayable) {
      thumbUrl = widget.item.isPathBased
          ? (widget.item.type == SFileType.image ? widget.vm.fileUrl(widget.item.path) : widget.vm.thumbnailUrlForPath(widget.item.path))
          : widget.vm.thumbnailUrl(widget.item.path);
    }

    final isDir = widget.item.isDirectory;

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
          if (v) {
            _scaleCtrl.forward();
            handleTVFocusScroll(v, context);
          } else {
            _scaleCtrl.reverse();
          }
        },
        onKeyEvent: _handleCardKey,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              decoration: BoxDecoration(
                color: _focused ? tokens.textPrimary : tokens.surface2,
                border: Border.all(color: _focused ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15), width: _focused ? 1 : 0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 78,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumbUrl != null)
                          Container(
                            color: tokens.background,
                            child: Opacity(
                              opacity: _focused ? 1.0 : 0.5,
                              child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.icon),
                            ),
                          )
                        else
                          Container(
                            color: isDir ? tokens.surface1 : tokens.surface2,
                            child: Center(
                              child: Opacity(
                                opacity: _focused ? 1.0 : 0.5,
                                child: Icon(widget.item.icon, color: _focused ? tokens.background : tokens.textPrimary, size: 40),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 22,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                      child: Text(
                        widget.item.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmMono(
                          color: _focused ? tokens.background : tokens.textSecondary,
                          fontSize: 10,
                          fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                          letterSpacing: 1,
                        ),
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
// TOP NAV BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _TopNavBtn extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TopNavBtn({required this.label, required this.isActive, required this.onTap});

  @override
  State<_TopNavBtn> createState() => _TopNavBtnState();
}

class _TopNavBtnState extends State<_TopNavBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Expanded(
      child: Actions(
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
            onTap: widget.onTap,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.isActive ? tokens.textPrimary : (_focused ? tokens.textPrimary.withValues(alpha: 0.04) : Colors.transparent),
                border: Border(right: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
              ),
              child: Text(
                widget.label,
                style: GoogleFonts.dmMono(
                  fontSize: 11,
                  fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 2,
                  color: widget.isActive ? tokens.background : tokens.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV BUTTON (MOBILE)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavBtn({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? tokens.textPrimary : Colors.transparent,
            border: Border(right: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmMono(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? tokens.background : tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HARDWARE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _HardwareBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final double? width;

  const _HardwareBtn({required this.label, required this.onTap, this.isPrimary = false, this.width});

  @override
  State<_HardwareBtn> createState() => _HardwareBtnState();
}

class _HardwareBtnState extends State<_HardwareBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bg = widget.isPrimary ? tokens.textPrimary : (_focused ? tokens.textPrimary.withValues(alpha: 0.04) : Colors.transparent);
    final fg = widget.isPrimary ? tokens.background : tokens.textPrimary;

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
          onTap: widget.onTap,
          child: Container(
            width: widget.width ?? 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              border: Border(left: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.dmMono(
                fontSize: 12,
                fontWeight: widget.isPrimary || _focused ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 2,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV STATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TVStationCard extends StatefulWidget {
  final Map<String, dynamic> station;
  final VoidCallback onTap;

  const _TVStationCard({required this.station, required this.onTap});

  @override
  State<_TVStationCard> createState() => _TVStationCardState();
}

class _TVStationCardState extends State<_TVStationCard> with SingleTickerProviderStateMixin {
  bool _focused = false;
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final nowPlaying = widget.station['nowPlaying'];
    final title = widget.station['name'].toString().toUpperCase();
    final itemTitle = nowPlaying != null ? nowPlaying['item']['title'].toString().toUpperCase() : 'AWAITING SIGNAL';

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
          if (v) {
            _scaleCtrl.forward();
            handleTVFocusScroll(v, context);
          } else {
            _scaleCtrl.reverse();
          }
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _focused ? tokens.textPrimary : tokens.surface2,
                border: Border.all(color: _focused ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15), width: _focused ? 4 : 0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(title, style: GoogleFonts.barlowCondensed(color: _focused ? tokens.background : tokens.textPrimary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1), maxLines: 1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: _focused ? tokens.background : tokens.textPrimary)),
                        child: Text('LIVE', style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: _focused ? tokens.background : tokens.textPrimary)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STATUS // NOW PLAYING', style: GoogleFonts.dmMono(fontSize: 10, color: _focused ? tokens.background.withValues(alpha:0.5) : tokens.textMuted, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(itemTitle, style: GoogleFonts.dmMono(fontSize: 12, color: _focused ? tokens.background : tokens.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
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
        autofocus: widget.autoFocus,
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: _focused ? (widget.isDestructive ? tokens.error : tokens.textPrimary) : Colors.transparent,
              border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.dmMono(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: _focused ? tokens.background : (widget.isDestructive ? tokens.error : tokens.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
