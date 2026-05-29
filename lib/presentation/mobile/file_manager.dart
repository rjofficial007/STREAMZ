// presentation/mobile/file_manager.dart
// ============================================================================
// STREAMZ — Mobile / Tablet File Manager (Brutalist Web Studio Edition)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/models/media_item.dart';
import '../client/client_viewmodel.dart';
import '../player/player_screen.dart';
import '../shared/file_item.dart';
import 'downloads_sheet.dart';

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

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  final String id;
  final String label;
  final IconData icon;
  final SFileType? filterType;
  const _Category({required this.id, required this.label, required this.icon, this.filterType});
}

const _kCategories = [
  _Category(id: 'recent', label: 'RECENT', icon: LucideIcons.history),
  _Category(id: 'images', label: 'IMAGES', icon: LucideIcons.image, filterType: SFileType.image),
  _Category(id: 'videos', label: 'VIDEOS', icon: LucideIcons.film, filterType: SFileType.video),
  _Category(id: 'audio', label: 'AUDIO', icon: LucideIcons.activity, filterType: SFileType.audio),
];

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SamsungFileManagerScreen extends StatefulWidget {
  const SamsungFileManagerScreen({super.key});

  @override
  State<SamsungFileManagerScreen> createState() => _SamsungFileManagerScreenState();
}

class _SamsungFileManagerScreenState extends State<SamsungFileManagerScreen> with TickerProviderStateMixin {
  final List<String?> _navStack = [null];
  String? get _currentPath => _navStack.last;

  List<SFileItem> _items = [];
  List<SFileItem> _allItems = [];
  bool _isLoading = true;
  String? _error;

  bool _isListView = false; // Defaulted to Grid View based on 3-column request
  bool _searchActive = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  String _sortBy = 'name';
  bool _sortAsc = true;
  String? _activeCategory;
  String? _activeCategoryLabel;

  late ClientViewModel _vm;

  // Aesthetic zero outer padding config
  final double _hPad = 0.0;
  final double _textPad = 16.0;

  String get _title {
    if (_activeCategory != null) return _activeCategoryLabel ?? 'FILES';
    if (_currentPath == null || _currentPath!.isEmpty) return 'SYS DIRECTORY';
    final parts = _currentPath!.replaceAll('\\', '/').split('/');
    return parts.where((s) => s.isNotEmpty).lastOrNull ?? 'ROOT';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm = context.read<ClientViewModel>();
      _loadHome();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data Methods ──────────────────────────────────────────────────────────

  Future<void> _loadHome() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _activeCategory = null;
    });
    final media = _vm.remoteMedia;
    _allItems = media.map((m) => SFileItem(name: m.title, path: m.id, isDirectory: false, size: 0, type: _parseType(m.type), isPathBased: false)).toList();
    await _loadPath('');
  }

  SFileType _parseType(String t) {
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
      _searchActive = false;
      _searchQuery = '';
      _searchCtrl.clear();
      _activeCategory = null;
    });
    try {
      final raw = await _vm.browseRemote(path);
      final items = raw.map((e) => SFileItem.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _items = _sort(items);
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

  List<SFileItem> _sort(List<SFileItem> items) {
    final dirs = items.where((i) => i.isDirectory).toList();
    final files = items.where((i) => !i.isDirectory).toList();
    int cmp(SFileItem a, SFileItem b) {
      int r = 0;
      switch (_sortBy) {
        case 'size': r = a.size.compareTo(b.size); break;
        case 'type': r = a.ext.compareTo(b.ext); break;
        default: r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAsc ? r : -r;
    }
    return [...(dirs..sort(cmp)), ...(files..sort(cmp))];
  }

  void _openCategory(_Category cat) {
    setState(() {
      _activeCategory = cat.id;
      _activeCategoryLabel = cat.label;
      _isLoading = false;
      _items = cat.id == 'recent' ? _sort(_allItems.take(50).toList()) : (cat.filterType != null ? _sort(_allItems.where((i) => i.type == cat.filterType).toList()) : []);
    });
  }

  void _navigateTo(String path) {
    _navStack.add(path);
    _loadPath(path);
  }

  bool _goBack() {
    if (_searchActive) {
      setState(() {
        _searchActive = false;
        _searchQuery = '';
        _searchCtrl.clear();
      });
      return true;
    }
    if (_activeCategory != null) {
      setState(() {
        _activeCategory = null;
        _activeCategoryLabel = null;
      });
      _navStack.clear();
      _navStack.add(null);
      _loadHome();
      return true;
    }
    if (_navStack.length > 1) {
      _navStack.removeLast();
      final prev = _navStack.last;
      if (prev == null) _loadHome();
      else _loadPath(prev);
      return true;
    }
    return false;
  }

  void _openItem(SFileItem item) {
    if (item.isDirectory) {
      _navigateTo(item.path);
      return;
    }
    if (!item.isPlayable) return;

    final playable = _items.where((i) => i.isPlayable).toList();
    final idx = playable.indexWhere((i) => i.path == item.path);
    final playlist = playable.map((i) => MediaItem(id: i.path, title: i.name, duration: 0, type: i.mediaType, folder: _title)).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          items: playlist.isEmpty ? [MediaItem(id: item.path, title: item.name, duration: 0, type: item.mediaType, folder: _title)] : playlist,
          startIndex: idx >= 0 ? idx : 0,
          isPathBased: item.isPathBased,
        ),
      ),
    );
  }

  void _triggerDownload(SFileItem item) {
    final mediaItem = MediaItem(id: item.path, title: item.name, duration: 0, type: item.mediaType, folder: 'Download');
    _vm.downloadMedia(item: mediaItem, isPathBased: item.isPathBased);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'DOWNLOADING ${item.name.toUpperCase()}',
          style: GoogleFonts.dmMono(color: kWebBlack, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kWebWhite,
        duration: const Duration(seconds: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  List<SFileItem> get _displayItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ── Build Methods ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = DS.isMobile(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (!_goBack()) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: kWebBlack,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(isMobile),
              ..._buildBodySlivers(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isMobile) {
    final iconSz = isMobile ? 20.0 : 22.0;
    final showNav = _searchActive || _currentPath != null || _activeCategory != null;

    return SliverAppBar(
      backgroundColor: kWebSurface,
      floating: true,
      elevation: 0,
      pinned: true,
      titleSpacing: 0,
      leading: showNav
          ? Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _searchActive
                  ? setState(() {
                _searchActive = false;
                _searchQuery = '';
                _searchCtrl.clear();
              })
                  : _goBack();
              return null;
            },
          ),
        },
        child: Focus(
          onKeyEvent: (_, ev) => handleTVSelectKey(
            ev,
            _searchActive
                ? () {
              setState(() {
                _searchActive = false;
                _searchQuery = '';
                _searchCtrl.clear();
              });
            }
                : _goBack,
          ),
          child: IconButton(
            icon: Icon(LucideIcons.chevronLeft, size: iconSz, color: kWebWhite),
            onPressed: _searchActive
                ? () => setState(() {
              _searchActive = false;
              _searchQuery = '';
              _searchCtrl.clear();
            })
                : _goBack,
          ),
        ),
      )
          : null,
      automaticallyImplyLeading: false,
      title: _searchActive
          ? Row(
        children: [
          if (!showNav) SizedBox(width: _textPad),
          Text('CMD>', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              autofocus: true,
              style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 12, letterSpacing: 1),
              cursorColor: kWebWhite,
              decoration: InputDecoration(
                hintText: 'SEARCH QUERY...',
                hintStyle: TextStyle(color: kWebTextMuted),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ],
      )
          : Padding(
        padding: EdgeInsets.only(left: showNav ? 0 : _textPad),
        child: Text(
          _title.toUpperCase(),
          style: GoogleFonts.barlowCondensed(
              color: kWebWhite,
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 4
          ),
        ),
      ),
      actions: [
        if (!_searchActive)
          Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  setState(() => _searchActive = true);
                  return null;
                },
              ),
            },
            child: Focus(
              onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => setState(() => _searchActive = true)),
              child: IconButton(
                icon: Icon(LucideIcons.search, size: iconSz, color: kWebText),
                onPressed: () => setState(() => _searchActive = true),
              ),
            ),
          ),
        if (_searchActive && _searchQuery.isNotEmpty)
          Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                  return null;
                },
              ),
            },
            child: Focus(
              onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              }),
              child: IconButton(
                icon: Icon(LucideIcons.x, size: iconSz, color: kWebTextMuted),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),
          ),
        if (!_searchActive)
          _SortMenuButton(
            sortBy: _sortBy,
            sortAsc: _sortAsc,
            isMobile: isMobile,
            onChanged: (by, asc) => setState(() {
              _sortBy = by;
              _sortAsc = asc;
              _items = _sort(_items);
            }),
          ),
        if (!_searchActive)
          Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  setState(() => _isListView = !_isListView);
                  return null;
                },
              ),
            },
            child: Focus(
              onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => setState(() => _isListView = !_isListView)),
              child: IconButton(
                icon: Icon(_isListView ? LucideIcons.layoutGrid : LucideIcons.list, size: iconSz, color: kWebText),
                onPressed: () => setState(() => _isListView = !_isListView),
              ),
            ),
          ),
        Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                showDownloadsSheet(context);
                return null;
              },
            ),
          },
          child: Focus(
            onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => showDownloadsSheet(context)),
            child: IconButton(
              icon: Icon(LucideIcons.download, size: iconSz, color: kWebText),
              onPressed: () => showDownloadsSheet(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kWebBorder, height: 1),
      ),
    );
  }

  List<Widget> _buildBodySlivers(bool isMobile) {
    if (_currentPath == null && _activeCategory == null && !_isLoading) {
      return _buildHomeSlivers(isMobile);
    }
    if (_isLoading) return _buildSkeletonSlivers(isMobile);
    if (_error != null) return _buildErrorSlivers(isMobile);

    final items = _displayItems;
    if (items.isEmpty) return _buildEmptySlivers(isMobile);

    return _isListView ? _buildListSlivers(items, isMobile) : _buildGridSlivers(items, isMobile);
  }

  // ── Home View Slivers ─────────────────────────────────────────────────────

  List<Widget> _buildHomeSlivers(bool isMobile) {
    return [
      SliverToBoxAdapter(child: SizedBox(height: isMobile ? 24 : 32)),

      // Quick Access Header
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _textPad),
          child: Text('QUICK ACCESS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: isMobile ? 12 : 16)),

      // Categories Grid (3 Columns)
      SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)), color: kWebBorder),
          child: GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            // Requested 3 crossAxisCount
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1
            ),
            itemCount: _kCategories.length,
            itemBuilder: (_, i) => _BrutalistInteractiveCard(
              onTap: () => _openCategory(_kCategories[i]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_kCategories[i].icon, color: kWebWhite, size: isMobile ? 22 : 26),
                  SizedBox(height: isMobile ? 7 : 10),
                  Text(
                    _kCategories[i].label,
                    style: GoogleFonts.dmMono(color: kWebText, fontSize: isMobile ? 9 : 10, letterSpacing: 1),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      SliverToBoxAdapter(child: SizedBox(height: isMobile ? 24 : 36)),

      // Sys Storage Header
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _textPad),
          child: Text('SYS STORAGE', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: isMobile ? 12 : 16)),

      // Storage Analysis Card
      SliverToBoxAdapter(child: _buildStorageCard(isMobile)),

      SliverToBoxAdapter(child: SizedBox(height: isMobile ? 12 : 16)),

      // Root Directory Button
      SliverToBoxAdapter(child: _buildRootButton(isMobile)),

      SliverToBoxAdapter(child: const SizedBox(height: 100)),
    ];
  }

  Widget _buildStorageCard(bool isMobile) {
    final imgs = _allItems.where((i) => i.type == SFileType.image).length;
    final vids = _allItems.where((i) => i.type == SFileType.video).length;
    final auds = _allItems.where((i) => i.type == SFileType.audio).length;
    final total = _allItems.length;
    final other = total - imgs - vids - auds;

    Widget legend(String label, int count, Color color) {
      return Row(
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: GoogleFonts.dmMono(color: kWebText, fontSize: 10))),
          Text(count.toString(), style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: kWebWhite)),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: kWebSurface,
        border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STORAGE ANALYSIS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Icon(LucideIcons.hardDrive, color: kWebTextMuted, size: 20),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          if (total > 0)
            SizedBox(
              height: isMobile ? 12 : 16,
              child: Row(
                children: [
                  if (vids > 0) Expanded(flex: vids, child: Container(color: kWebWhite)),
                  if (imgs > 0) Expanded(flex: imgs, child: Container(color: Colors.white70)),
                  if (auds > 0) Expanded(flex: auds, child: Container(color: Colors.white30)),
                  if (other > 0) Expanded(flex: other, child: Container(color: kWebSurface2)),
                ],
              ),
            )
          else
            Container(height: isMobile ? 12 : 16, color: kWebSurface2),
          SizedBox(height: isMobile ? 20 : 24),
          Row(
            children: [
              Expanded(child: Column(children: [legend('VIDEOS', vids, kWebWhite), const SizedBox(height: 8), legend('IMAGES', imgs, Colors.white70)])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [legend('AUDIO', auds, Colors.white30), const SizedBox(height: 8), legend('OTHER', other, kWebSurface2)])),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Container(height: 1, color: kWebBorder),
          SizedBox(height: isMobile ? 12 : 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL INDEXED FILES', style: GoogleFonts.dmMono(fontSize: 10, color: kWebTextMuted, letterSpacing: 1)),
              Text('$total', style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.bold, color: kWebWhite)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRootButton(bool isMobile) {
    return Container(
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: kWebBorder))),
      child: _BrutalistInteractiveCard(
        onTap: () {
          _navStack.add('');
          _loadPath('');
        },
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Row(
            children: [
              Icon(LucideIcons.terminal, size: isMobile ? 24 : 28, color: kWebWhite),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ROOT DIRECTORY', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 3),
                    Text('${_allItems.length} FILES INDEXED', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: isMobile ? 9 : 10, letterSpacing: 1)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: kWebTextMuted, size: isMobile ? 16 : 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Skeleton & State Slivers ──────────────────────────────────────────────

  List<Widget> _buildSkeletonSlivers(bool isMobile) {
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, i) => Container(
            height: isMobile ? 60 : 72,
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kWebBorder), top: i == 0 ? BorderSide(color: kWebBorder) : BorderSide.none),
                color: kWebSurface
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(width: isMobile ? 40 : 52, height: isMobile ? 40 : 52, color: kWebSurface2),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 11, width: double.infinity, color: kWebSurface2),
                      const SizedBox(height: 6),
                      Container(width: 80, height: 9, color: kWebSurface2),
                    ],
                  ),
                ),
              ],
            ),
          ),
          childCount: 12,
        ),
      ),
    ];
  }

  List<Widget> _buildEmptySlivers(bool isMobile) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
            decoration: BoxDecoration(border: Border.all(color: kWebBorder, style: BorderStyle.solid)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.folderOpen, size: isMobile ? 48 : 60, color: kWebTextMuted),
                SizedBox(height: isMobile ? 14 : 20),
                Text('DIRECTORY EMPTY', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 4)),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildErrorSlivers(bool isMobile) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
            decoration: BoxDecoration(border: Border.all(color: kWebBorder, style: BorderStyle.solid)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.alertTriangle, size: isMobile ? 48 : 60, color: kWebTextMuted),
                SizedBox(height: isMobile ? 14 : 20),
                Text('CONNECTION FAILED', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text((_error ?? 'UNKNOWN ERROR').toUpperCase(), style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
                SizedBox(height: isMobile ? 24 : 32),
                GestureDetector(
                  onTap: () => _currentPath != null ? _loadPath(_currentPath!) : _loadHome(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: kWebWhite)),
                    child: Text('RETRY', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  // ── List & Grid Slivers ───────────────────────────────────────────────────

  List<Widget> _buildListSlivers(List<SFileItem> items, bool isMobile) {
    return [
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (_, i) => _FileListTile(
                item: items[i],
                vm: _vm,
                isFirst: i == 0,
                onTap: () => _openItem(items[i]),
                onDownload: () => _triggerDownload(items[i])
            ),
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildGridSlivers(List<SFileItem> items, bool isMobile) {
    final dirs = items.where((i) => i.isDirectory).toList();
    final files = items.where((i) => !i.isDirectory).toList();

    // Exact match: 3 crossAxisCount brutalist layout
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      childAspectRatio: 1.0,
      crossAxisSpacing: 1,
      mainAxisSpacing: 1,
    );

    return [
      SliverToBoxAdapter(child: SizedBox(height: isMobile ? 16 : 24)),

      if (dirs.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(_textPad, 0, _textPad, 8),
            child: Text('DIRECTORIES', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)), color: kWebBorder),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: gridDelegate,
              itemCount: dirs.length,
              itemBuilder: (_, i) => _FileGridCard(item: dirs[i], vm: _vm, onTap: () => _openItem(dirs[i]), onDownload: () => _triggerDownload(dirs[i])),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: isMobile ? 24 : 32)),
      ],

      if (files.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(_textPad, 0, _textPad, 8),
            child: Text('FILES', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 2)),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(bottom: 100),
            decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)), color: kWebBorder),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: gridDelegate,
              itemCount: files.length,
              itemBuilder: (_, i) => _FileGridCard(item: files[i], vm: _vm, onTap: () => _openItem(files[i]), onDownload: () => _triggerDownload(files[i])),
            ),
          ),
        ),
      ],
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRUTALIST INTERACTIVE CARD (For generic buttons/tiles)
// ─────────────────────────────────────────────────────────────────────────────

class _BrutalistInteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BrutalistInteractiveCard({required this.child, required this.onTap});

  @override
  State<_BrutalistInteractiveCard> createState() => _BrutalistInteractiveCardState();
}

class _BrutalistInteractiveCardState extends State<_BrutalistInteractiveCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isFocused = true),
      onTapUp: (_) {
        setState(() => _isFocused = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isFocused = false),
      child: Container(
        decoration: BoxDecoration(
          color: _isFocused ? kWebWhite.withOpacity(0.1) : kWebSurface2,
        ),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILE LIST TILE
// ─────────────────────────────────────────────────────────────────────────────

class _FileListTile extends StatefulWidget {
  final SFileItem item;
  final ClientViewModel vm;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _FileListTile({required this.item, required this.vm, required this.isFirst, required this.onTap, required this.onDownload});

  @override
  State<_FileListTile> createState() => _FileListTileState();
}

class _FileListTileState extends State<_FileListTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = DS.isMobile(context);
    final iconBoxSz = isMobile ? 44.0 : 52.0;

    String? thumbUrl;
    if (widget.item.isPlayable) {
      if (widget.item.isPathBased) {
        thumbUrl = widget.item.type == SFileType.image ? widget.vm.fileUrl(widget.item.path) : widget.vm.thumbnailUrlForPath(widget.item.path);
      } else {
        thumbUrl = widget.vm.thumbnailUrl(widget.item.path);
      }
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isFocused = true),
      onTapUp: (_) {
        setState(() => _isFocused = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isFocused = false),
      child: Container(
        decoration: BoxDecoration(
          color: _isFocused ? kWebWhite.withOpacity(0.1) : kWebSurface,
          border: Border(bottom: BorderSide(color: kWebBorder), top: widget.isFirst ? BorderSide(color: kWebBorder) : BorderSide.none),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 8 : 11),
        child: Row(
          children: [
            // Icon / thumbnail
            if (thumbUrl != null)
              Container(
                width: iconBoxSz,
                height: iconBoxSz,
                decoration: BoxDecoration(border: Border.all(color: kWebBorder), color: kWebBlack),
                child: ColorFiltered(
                  colorFilter: _isFocused ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply) : kGreyscale,
                  child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.icon),
                ),
              )
            else
              Container(
                width: iconBoxSz,
                height: iconBoxSz,
                decoration: BoxDecoration(
                  color: kWebSurface2,
                  border: Border.all(color: kWebBorder),
                ),
                child: Icon(widget.item.icon, color: kWebText, size: iconBoxSz * 0.45),
              ),
            SizedBox(width: isMobile ? 10 : 14),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (widget.item.isDirectory)
                        Text('${widget.item.itemCount} ITEMS', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: isMobile ? 9 : 10, letterSpacing: 1))
                      else if (widget.item.sizeLabel.isNotEmpty) ...[
                        Text(widget.item.sizeLabel, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: isMobile ? 9 : 10, letterSpacing: 1)),
                        Text('  ///  ', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: isMobile ? 9 : 10, letterSpacing: 1)),
                      ],
                      Text(widget.item.typeLabel, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: isMobile ? 9 : 10, letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
            ),
            // Action button
            if (widget.item.isDirectory)
              Icon(LucideIcons.chevronRight, color: kWebTextMuted, size: isMobile ? 15 : 17)
            else
              Actions(
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      widget.onDownload();
                      return null;
                    },
                  ),
                },
                child: Focus(
                  onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onDownload),
                  child: IconButton(
                    icon: Icon(LucideIcons.download, color: kWebWhite, size: isMobile ? 20 : 22),
                    onPressed: widget.onDownload,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILE GRID CARD (Match ModernMobileUIScreen 78/22 Split)
// ─────────────────────────────────────────────────────────────────────────────

class _FileGridCard extends StatefulWidget {
  final SFileItem item;
  final ClientViewModel vm;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _FileGridCard({required this.item, required this.vm, required this.onTap, required this.onDownload});

  @override
  State<_FileGridCard> createState() => _FileGridCardState();
}

class _FileGridCardState extends State<_FileGridCard> {
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = DS.isMobile(context);
    final isDir = widget.item.isDirectory;

    String? thumbUrl;
    if (widget.item.isPlayable) {
      if (widget.item.isPathBased) {
        thumbUrl = widget.item.type == SFileType.image ? widget.vm.fileUrl(widget.item.path) : widget.vm.thumbnailUrlForPath(widget.item.path);
      } else {
        thumbUrl = widget.vm.thumbnailUrl(widget.item.path);
      }
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        color: _isFocused || _isPressed ? kWebWhite : kWebSurface2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster area (78%)
            Expanded(
              flex: 78,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbUrl != null)
                    Container(
                      color: kWebBlack,
                      child: ColorFiltered(
                        colorFilter: (_isFocused || _isPressed) ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply) : kGreyscale,
                        child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.icon),
                      ),
                    )
                  else
                    Container(
                      color: isDir ? kWebSurface : kWebSurface2,
                      child: Center(
                        child: Icon(widget.item.icon, color: isDir ? kWebWhite : kWebTextMuted, size: isMobile ? (isDir ? 32 : 24) : (isDir ? 42 : 32)),
                      ),
                    ),

                  // Top-Left Badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(border: Border.all(color: kWebBorder), color: kWebBlack),
                      child: Text(
                        isDir ? '${widget.item.itemCount} ITEMS' : widget.item.typeLabel,
                        style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),

                  // Bottom-Right Download Button (Files Only)
                  if (!isDir)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Actions(
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (_) {
                              widget.onDownload();
                              return null;
                            },
                          ),
                        },
                        child: Focus(
                          onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onDownload),
                          child: GestureDetector(
                            onTap: widget.onDownload,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(border: Border.all(color: kWebBorder), color: kWebBlack),
                              child: Icon(LucideIcons.download, color: kWebWhite, size: isMobile ? 12 : 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info area (22%)
            Expanded(
              flex: 22,
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: kWebSurface,
                  border: Border(top: BorderSide(color: kWebBorder)),
                ),
                child: Text(
                  widget.item.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmMono(
                    color: _isFocused || _isPressed ? kWebBlack : kWebText,
                    fontSize: isMobile ? 9 : 10,
                    fontWeight: (_isFocused || _isPressed) ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SORT MENU
// ─────────────────────────────────────────────────────────────────────────────

class _SortMenuButton extends StatelessWidget {
  final String sortBy;
  final bool sortAsc;
  final bool isMobile;
  final void Function(String by, bool asc) onChanged;

  const _SortMenuButton({required this.sortBy, required this.sortAsc, required this.isMobile, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(LucideIcons.arrowDownWideNarrow, size: isMobile ? 20 : 22, color: kWebText),
      color: kWebSurface,
      shape: Border.all(color: kWebBorder),
      onSelected: (v) => onChanged(v, v == sortBy ? !sortAsc : true),
      itemBuilder: (_) => [_sortItem('name', 'NAME', isMobile), _sortItem('size', 'SIZE', isMobile), _sortItem('type', 'TYPE', isMobile)],
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label, bool isMobile) {
    final active = value == sortBy;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.dmMono(color: active ? kWebWhite : kWebText, fontSize: isMobile ? 11 : 13, fontWeight: active ? FontWeight.bold : FontWeight.normal, letterSpacing: 1),
          ),
          const Spacer(),
          if (active) Icon(sortAsc ? LucideIcons.arrowUp : LucideIcons.arrowDown, size: isMobile ? 13 : 15, color: kWebWhite),
        ],
      ),
    );
  }
}