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
import '../../core/theme/design_tokens.dart';
import '../../domain/models/media_item.dart';
import '../client/client_viewmodel.dart';
import '../player/player_screen.dart';
import '../shared/file_item.dart';

// --- Web UI Color Palette & Styles ---
const Color kWebBlack = Color(0xFF000000);
const Color kWebSurface = Color(0xFF0A0A0A);
const Color kWebSurface2 = Color(0xFF111111);
const Color kWebWhite = Color(0xFFFFFFFF);
final Color kWebBorder = Colors.white.withValues(alpha: 0.15);
final Color kWebTextMuted = Colors.white.withValues(alpha: 0.3);
final Color kWebText = Colors.white.withValues(alpha: 0.6);

const ColorFilter kGreyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      1, 0,
]);

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

  List<Map<String, dynamic>> _stations = [];

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
      final vm = context.read<ClientViewModel>();
      final media = vm.remoteMedia;
      _stations = vm.stations;
      _allItems = media.map((m) => SFileItem(name: m.title, path: m.id, isDirectory: false, size: 0, type: _parseType(m.type), isPathBased: false)).toList();
      await _loadPath('');
    } catch (_) {
      await _loadPath('');
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
    if (cat == 'root') {
      _navStack.clear();
      _navStack.add('');
      _loadPath('');
    } else if (cat == 'live') {
      setState(() {
        _isLoading = false;
      });
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
          builder: (_) => PlayerScreen(
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
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
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
        backgroundColor: kWebBlack,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final sidebarW = (constraints.maxWidth * 0.14).clamp(180.0, 260.0);

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
                              // COMPACT HEADER
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
      decoration: BoxDecoration(
        color: kWebSurface,
        border: Border(right: BorderSide(color: kWebBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, (size.height * 0.05).clamp(16.0, 32.0), 16, 16),
            child: Text(
              'STREAMZ',
              style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: (size.width * 0.015).clamp(20.0, 28.0), fontWeight: FontWeight.w900, letterSpacing: 3),
            ),
          ),
          Container(height: 1, color: kWebBorder),
          _TVSidebarBtn(icon: LucideIcons.hardDrive, label: 'NETWORK FS', isActive: _activeCategory == 'root', autoFocus: true, onTap: () => _switchCategory('root', null)),
          _TVSidebarBtn(icon: LucideIcons.history, label: 'RECENT', isActive: _activeCategory == 'recent', onTap: () => _switchCategory('recent', null)),
          _TVSidebarBtn(icon: LucideIcons.radio, label: 'LIVE BROADCAST', isActive: _activeCategory == 'live', isLive: _stations.isNotEmpty, onTap: () => _switchCategory('live', null)),
          _TVSidebarBtn(icon: LucideIcons.film, label: 'VIDEOS', isActive: _activeCategory == 'video', onTap: () => _switchCategory('video', SFileType.video)),
          _TVSidebarBtn(icon: LucideIcons.music, label: 'AUDIO', isActive: _activeCategory == 'audio', onTap: () => _switchCategory('audio', SFileType.audio)),
          _TVSidebarBtn(icon: LucideIcons.image, label: 'PHOTOS', isActive: _activeCategory == 'image', onTap: () => _switchCategory('image', SFileType.image)),
          const Spacer(),
          Container(height: 1, color: kWebBorder),
          _TVSidebarBtn(icon: LucideIcons.logOut, label: 'SYS EXIT', isActive: false, isExit: true, onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  // ── Compact Header ────────────────────────────────────────────────────────

  Widget _buildHeader(BoxConstraints constraints, Size size) {
    // Smaller font clamping to keep the header extremely tight
    final titleFs = (constraints.maxWidth * 0.025).clamp(20.0, 36.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: kWebSurface,
        border: Border(bottom: BorderSide(color: kWebBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      _title,
                      style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: titleFs, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: 2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_stations.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: kWebWhite)),
                        child: Text('LIVE', style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: kWebWhite)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4), // Tight gap
                Text(
                  'PATH // ROOT/FS',
                  style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 12, letterSpacing: 2), // Fixed small sub-font
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: (constraints.maxWidth * 0.35).clamp(240.0, 400.0), // Narrower max width
            height: 44, // Significantly reduced height (from 60)
            decoration: BoxDecoration(color: kWebBlack, border: Border.all(color: kWebBorder)),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Text('CMD>', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 14)),
                const SizedBox(width: 10),
                Expanded(
                  child: Center(
                    child: TextField(
                      focusNode: _searchFocusNode,
                      style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, letterSpacing: 1), // Scaled down to match 44px height
                      cursorColor: kWebWhite,
                      decoration: InputDecoration(
                        hintText: 'SEARCH QUERY...',
                        hintStyle: TextStyle(color: kWebTextMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
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

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(Size size) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: kWebWhite, strokeWidth: 2));
    if (_error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
          decoration: BoxDecoration(border: Border.all(color: kWebBorder, style: BorderStyle.solid)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertTriangle, size: 64, color: kWebTextMuted),
              const SizedBox(height: 24),
              Text('CONNECTION FAILED', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text(_error!.toUpperCase(), style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => _currentPath != null ? _loadPath(_currentPath!) : _loadHome(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(border: Border.all(color: kWebWhite)),
                  child: Text('RETRY SIGNAL', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeCategory == 'live') {
      if (_stations.isEmpty) {
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
            decoration: BoxDecoration(border: Border.all(color: kWebBorder, style: BorderStyle.solid)),
            child: Text('NO ACTIVE BROADCASTS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 16, letterSpacing: 4)),
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(color: kWebBorder),
        child: GridView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.only(bottom: 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: _stations.length,
          itemBuilder: (_, i) => _TVStationCard(
            station: _stations[i],
            onTap: () => _tuneIn(_stations[i]),
          ),
        ),
      );
    }

    final filtered = _displayItems;
    if (filtered.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
          decoration: BoxDecoration(border: Border.all(color: kWebBorder, style: BorderStyle.solid)),
          child: Text('0 SIGNALS FOUND', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 16, letterSpacing: 4)),
        ),
      );
    }

    // Edge to Edge 5-column TV Brutalist Grid
    return Container(
      decoration: BoxDecoration(color: kWebBorder), // Background for 1px grid lines
      child: GridView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.0,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _TVGridCard(item: filtered[i], vm: context.read<ClientViewModel>(), onTap: () => _openItem(filtered[i]), onLongPress: () => _showOptionsModal(filtered[i])),
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
        builder: (_) => PlayerScreen(items: mediaItems, startIndex: widget.startIndex, isPathBased: widget.playlist[widget.startIndex].isPathBased),
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
                            child: ColorFiltered(
                              colorFilter: _focused ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply) : kGreyscale,
                              child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.icon),
                            ),
                          )
                        else
                          Container(
                            color: isDir ? kWebSurface : kWebSurface2,
                            child: Center(
                              child: Icon(widget.item.icon, color: isDir ? kWebWhite : kWebTextMuted, size: 40),
                            ),
                          ),

                        // Positioned(
                        //   top: 4,
                        //   left: 4,
                        //   child: Container(
                        //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        //     decoration: BoxDecoration(border: Border.all(color: kWebBorder), color: kWebBlack),
                        //     child: Text(
                        //       isDir ? '${widget.item.itemCount} ITEMS' : widget.item.typeLabel,
                        //       style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 22,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: kWebBorder))),
                      child: Text(
                        widget.item.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmMono(
                          color: _focused ? kWebBlack : kWebText,
                          fontSize: 14,
                          fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                          letterSpacing: 2,
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
// TV SIDEBAR BUTTON (COMPACT)
// ─────────────────────────────────────────────────────────────────────────────

class _TVSidebarBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool autoFocus;
  final bool isExit;
  final bool isLive;

  const _TVSidebarBtn({required this.icon, required this.label, required this.isActive, required this.onTap, this.autoFocus = false, this.isExit = false, this.isLive = false});

  @override
  State<_TVSidebarBtn> createState() => _TVSidebarBtnState();
}

class _TVSidebarBtnState extends State<_TVSidebarBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.isActive;

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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _focused ? (widget.isExit ? Colors.redAccent : kWebWhite) : (widget.isActive ? kWebWhite.withValues(alpha: 0.05) : Colors.transparent),
              border: Border(
                  bottom: BorderSide(color: kWebBorder),
                  right: BorderSide(color: _focused ? (widget.isExit ? Colors.redAccent : kWebWhite) : Colors.transparent, width: 4)
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: _focused ? kWebBlack : (active ? (widget.isLive ? DS.accent : kWebWhite) : kWebTextMuted)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.dmMono(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      letterSpacing: 1,
                      color: _focused ? kWebBlack : (active ? kWebWhite : kWebTextMuted),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isLive)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: DS.accent, shape: BoxShape.circle),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: _focused ? (widget.isDestructive ? Colors.redAccent : kWebWhite) : Colors.transparent,
              border: Border(bottom: BorderSide(color: kWebBorder)),
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.dmMono(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: _focused ? kWebBlack : (widget.isDestructive ? Colors.redAccent : kWebWhite),
              ),
            ),
          ),
        ),
      ),
    );
  }
}