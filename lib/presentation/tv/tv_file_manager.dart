// presentation/tv/tv_file_manager.dart
// ============================================================================
// STREAMZ — TV File Manager (Brutalist Web Studio Edition)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/atmospheric_background.dart';
import 'package:streamz/presentation/shared/file_item.dart';
import 'package:streamz/presentation/tv/tv_player_screen.dart';

// --- Web UI Color Palette & Styles (Sync with TVHomeScreen) ---
// DEPRECATED: Use context.tokens instead
const Color kWebBlack = DS.bg;
const Color kWebSurface = DS.surface1;
const Color kWebSurface2 = DS.surface2;
const Color kWebWhite = DS.accent;
const Color kWebBorder = DS.borderDefault;
const Color kWebTextMuted = DS.textMuted;
const Color kWebText = DS.textSecondary;

class TVFileManagerScreen extends StatefulWidget {
  const TVFileManagerScreen({super.key});

  @override
  State<TVFileManagerScreen> createState() => _TVFileManagerScreenState();
}

class _TVFileManagerScreenState extends State<TVFileManagerScreen> {
  final List<String?> _navStack = [null];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isScrolled = false;

  List<SFileItem> _items = [];
  List<SFileItem> _allItems = [];
  bool _isLoading = true;
  String? _error;

  String _searchQuery = '';
  String _activeCategory = 'video';

  List<SFileItem> _activePlaylist = [];
  int _activePlayIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHome();
    });
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 50 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
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
      final items = raw.map(SFileItem.fromJson).toList()
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
      _navStack
        ..clear()
        ..add('');
      _loadPath('');
    } else if (cat == 'station') {
      context.read<ClientViewModel>().refresh();
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _items = filter != null ? _allItems.where((i) => i.type == filter).toList() : [];
        _isLoading = false;
      });
    }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
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

  Future<void> _tuneIn(BroadcastStation station) async {
    final vm = context.read<ClientViewModel>();
    final res = await vm.joinStation(station.id);
    if (res != null && mounted) {
      unawaited(context.push('/tv-player', extra: {
        'items': res.playlist,
        'startIndex': res.itemIndex,
        'isPathBased': false,
        'startOffset': res.position,
        'autoPlay': !res.isPaused,
      }));
    }
  }

  void _triggerDownload(SFileItem item) {
    final mediaItem = MediaItem(id: item.path, title: item.name, duration: 0, type: item.mediaType, folder: 'Download');
    context.read<ClientViewModel>().downloadMedia(item: mediaItem, isPathBased: item.isPathBased);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'CMD // DOWNLOADING ${item.name.toUpperCase()}',
          style: GoogleFonts.dmMono(color: kWebBlack, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        backgroundColor: kWebWhite,
        duration: const Duration(seconds: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  void _showOptionsModal(SFileItem item) {
    final size = MediaQuery.sizeOf(context);
    showGeneralDialog(
      context: context,
      barrierColor: kWebBlack.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      pageBuilder: (ctx, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: (size.width * 0.4).clamp(400.0, 600.0),
            decoration: BoxDecoration(
              color: kWebSurface,
              border: Border.all(color: kWebWhite, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text(
                      item.name.toUpperCase(),
                      style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1),
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
    final vm = context.watch<ClientViewModel>();
    final size = MediaQuery.sizeOf(context);
    const sidePadding = 0.0;

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
        backgroundColor: kWebBlack,
        extendBodyBehindAppBar: true,
        body: AtmosphericBackground(
          child: Stack(
            children: [
              CustomScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
                // Persistent TV Top Bar
                SliverAppBar(
                  backgroundColor: _isScrolled ? kWebSurface : Colors.transparent,
                  floating: true,
                  elevation: 0,
                  pinned: true,
                  toolbarHeight: (size.height * 0.08).clamp(50.0, 80.0),
                  leadingWidth: sidePadding + 48,
                  leading: Padding(
                    padding: EdgeInsets.zero,
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
                        onFocusChange: (f) {
                          if (f) Scrollable.ensureVisible(context, alignment: 0.0, duration: const Duration(milliseconds: 250));
                        },
                        onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
                          if (!_goBack()) Navigator.pop(context);
                        }),
                        child: IconButton(
                          icon: Icon(LucideIcons.arrowLeft, color: kWebWhite, size: (size.width * 0.015).clamp(20.0, 28.0)),
                          onPressed: () {
                            if (!_goBack()) Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    'STREAMZ',
                    style: GoogleFonts.barlowCondensed(fontSize: (size.width * 0.015).clamp(18.0, 28.0), letterSpacing: 4, color: kWebWhite, fontWeight: FontWeight.w900),
                  ),
                  centerTitle: false,
                  actions: [
                    Center(
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, color: kWebWhite),
                          const SizedBox(width: DS.s8),
                          Text(
                            'TGT // ${vm.targetIp}',
                            style: GoogleFonts.dmMono(color: kWebText, fontSize: (size.width * 0.008).clamp(9.0, 12.0)),
                          ),
                          const SizedBox(width: DS.s24),
                        ],
                      ),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: AnimatedOpacity(
                      opacity: _isScrolled ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(color: kWebBorder, height: 1),
                    ),
                  ),
                ),

                // Category Rail
                SliverToBoxAdapter(
                  child: Container(
                    height: (size.height * 0.08).clamp(50.0, 70.0),
                    margin: EdgeInsets.zero,
                    decoration: const BoxDecoration(
                      border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)),
                    ),
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
                ),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          // Move focus down to the first item in the grid
                          node.focusInDirection(TraversalDirection.down);
                          return KeyEventResult.handled;
                        }
                        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          // Move focus up to the category rail
                          node.focusInDirection(TraversalDirection.up);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: kWebSurface,
                          border: Border.all(color: kWebBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.search, color: kWebTextMuted, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                focusNode: _searchFocusNode,
                                onChanged: (v) => setState(() => _searchQuery = v),
                                style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, letterSpacing: 1),
                                decoration: InputDecoration(
                                  hintText: 'SEARCH SIGNALS...',
                                  hintStyle: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                _buildSliverContent(context, size, sidePadding, vm),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
        ),
      ),
    ));
  }

  Widget _buildSliverContent(BuildContext context, Size size, double sidePadding, ClientViewModel vm) {
    if (_isLoading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kWebWhite, strokeWidth: 2)));
    
    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
            decoration: BoxDecoration(border: Border.all(color: kWebBorder, style: BorderStyle.solid)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, size: 64, color: kWebTextMuted),
                const SizedBox(height: 24),
                Text('SIGNAL ERROR // ${_error?.toUpperCase()}', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, letterSpacing: 2)),
                const SizedBox(height: 32),
                _HardwareBtn(label: 'RETRY CONNECTION', width: 240, onTap: _loadHome),
              ],
            ),
          ),
        ),
      );
    }

    if (_activeCategory == 'station') {
      final stations = vm.stations;
      if (stations.isEmpty) {
        return SliverFillRemaining(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
              decoration: BoxDecoration(border: Border.all(color: kWebBorder, style: BorderStyle.solid)),
              child: Text('NO ACTIVE BROADCASTS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 16, letterSpacing: 4)),
            ),
          ),
        );
      }
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: sidePadding),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) => _TVStationCard(
              station: stations[i],
              onTap: () => _tuneIn(stations[i]),
            ),
            childCount: stations.length,
          ),
        ),
      );
    }

    final filtered = _displayItems;
    if (filtered.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
            decoration: BoxDecoration(border: Border.all(color: kWebBorder, style: BorderStyle.solid)),
            child: Text('0 SIGNALS FOUND', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 16, letterSpacing: 4)),
          ),
        ),
      );
    }

    final crossAxisCount = (size.width ~/ 220).clamp(3, 10);

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: sidePadding),
      sliver: SliverGrid(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE TV PLAYER (Logic Guard)
// ─────────────────────────────────────────────────────────────────────────────

class _TVInlinePlayer extends StatefulWidget {

  const _TVInlinePlayer({required this.playlist, required this.startIndex, required this.vm, required this.onClose});
  final List<SFileItem> playlist;
  final int startIndex;
  final ClientViewModel vm;
  final VoidCallback onClose;

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

  const _TVGridCard({required this.item, required this.vm, required this.onTap, required this.onLongPress});
  final SFileItem item;
  final ClientViewModel vm;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _focused ? kWebWhite : kWebSurface2,
                border: Border.all(color: _focused ? kWebWhite : kWebBorder, width: _focused ? 4 : 0),
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
                            color: kWebBlack,
                            child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.icon),
                          )
                        else
                          Container(
                            color: isDir ? kWebSurface : kWebSurface2,
                            child: Center(
                              child: Icon(widget.item.icon, color: _focused ? kWebBlack : kWebWhite, size: 40),
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
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kWebBorder))),
                      child: Text(
                        widget.item.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmMono(
                          color: _focused ? kWebBlack : kWebText,
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

  const _TopNavBtn({required this.label, required this.isActive, required this.onTap});
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_TopNavBtn> createState() => _TopNavBtnState();
}

class _TopNavBtnState extends State<_TopNavBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Expanded(
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
                color: widget.isActive ? kWebWhite : (_focused ? kWebWhite.withValues(alpha: 0.1) : Colors.transparent),
                border: const Border(right: BorderSide(color: kWebBorder)),
              ),
              child: Text(
                widget.label,
                style: GoogleFonts.dmMono(
                  fontSize: 11,
                  fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 2,
                  color: widget.isActive ? kWebBlack : kWebWhite,
                ),
              ),
            ),
          ),
        ),
      ),
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// HARDWARE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _HardwareBtn extends StatefulWidget {

  const _HardwareBtn({required this.label, required this.onTap, this.width});
  final String label;
  final VoidCallback onTap;
  final double? width;

  @override
  State<_HardwareBtn> createState() => _HardwareBtnState();
}

class _HardwareBtnState extends State<_HardwareBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bg = _focused ? kWebWhite.withValues(alpha: 0.1) : Colors.transparent;
    const fg = kWebWhite;

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
              border: const Border(left: BorderSide(color: kWebBorder)),
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.dmMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
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

  const _TVStationCard({required this.station, required this.onTap});
  final BroadcastStation station;
  final VoidCallback onTap;

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
    final nowPlaying = widget.station.nowPlaying;
    final title = widget.station.name.toUpperCase();
    final itemTitle = nowPlaying != null ? nowPlaying.item.title.toUpperCase() : 'AWAITING SIGNAL';

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
                color: _focused ? kWebWhite : kWebSurface2,
                border: Border.all(color: _focused ? kWebWhite : kWebBorder, width: _focused ? 4 : 0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(title, style: GoogleFonts.barlowCondensed(color: _focused ? kWebBlack : kWebWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1), maxLines: 1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: _focused ? kWebBlack : kWebWhite)),
                        child: Text('LIVE', style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: _focused ? kWebBlack : kWebWhite)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STATUS // NOW PLAYING', style: GoogleFonts.dmMono(fontSize: 10, color: _focused ? kWebBlack.withValues(alpha:0.5) : kWebTextMuted, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(itemTitle, style: GoogleFonts.dmMono(fontSize: 12, color: _focused ? kWebBlack : kWebText), maxLines: 1, overflow: TextOverflow.ellipsis),
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

  const _TVModalBtn({required this.label, required this.onTap, this.autoFocus = false, this.isDestructive = false});
  final String label;
  final VoidCallback onTap;
  final bool autoFocus;
  final bool isDestructive;

  @override
  State<_TVModalBtn> createState() => _TVModalBtnState();
}

class _TVModalBtnState extends State<_TVModalBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Actions(
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
              color: _focused ? (widget.isDestructive ? DS.danger : kWebWhite) : Colors.transparent,
              border: const Border(bottom: BorderSide(color: kWebBorder)),
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.dmMono(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: _focused ? kWebBlack : (widget.isDestructive ? DS.danger : kWebWhite),
              ),
            ),
          ),
        ),
      ),
    );
}
