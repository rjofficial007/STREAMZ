// presentation/mobile/file_manager.dart
// ============================================================================
// STREAMZ — Mobile / Tablet File Manager (Brutalist Web Studio Edition)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/mobile/downloads_sheet.dart';
import 'package:streamz/presentation/player/player_screen.dart';
import 'package:streamz/presentation/shared/file_item.dart';


// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  const _Category({required this.id, required this.label, required this.icon, this.filterType});
  final String id;
  final String label;
  final IconData icon;
  final SFileType? filterType;
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
  List<BroadcastStation> _stations = [];
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
  final double _textPad = 16.0;

  String get _title {
    if (_activeCategory != null) return _activeCategoryLabel ?? 'FILES';
    if (_currentPath == null || _currentPath!.isEmpty) return 'SYS DIRECTORY';
    final parts = _currentPath!.replaceAll(r'\', '/').split('/');
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
    final vm = context.read<ClientViewModel>();
    final media = vm.remoteMedia;
    _stations = vm.stations;
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
      final items = raw.map(SFileItem.fromJson).toList();
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
      var r = 0;
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
      if (cat.id == 'live') {
        _items = []; // Stations are handled separately in _buildBodySlivers
      } else {
        _items = cat.id == 'recent' ? _sort(_allItems.take(50).toList()) : (cat.filterType != null ? _sort(_allItems.where((i) => i.type == cat.filterType).toList()) : []);
      }
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
      _navStack
        ..clear()
        ..add(null);
      _loadHome();
      return true;
    }
    if (_navStack.length > 1) {
      _navStack.removeLast();
      final prev = _navStack.last;
      if (prev == null) {
        _loadHome();
      } else {
        _loadPath(prev);
      }
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

  Future<void> _tuneIn(BroadcastStation station) async {
    final res = await _vm.joinStation(station.id);
    if (res != null && mounted) {
      unawaited(context.push('/player', extra: {
        'items': res.playlist,
        'startIndex': res.itemIndex,
        'isPathBased': false,
        'startOffset': res.position,
      }));
    }
  }

  void _triggerDownload(SFileItem item) {
    final tokens = context.tokens;
    final mediaItem = MediaItem(id: item.path, title: item.name, duration: 0, type: item.mediaType, folder: 'Download');
    _vm.downloadMedia(item: mediaItem, isPathBased: item.isPathBased);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'DOWNLOADING ${item.name.toUpperCase()}',
          style: GoogleFonts.dmMono(color: tokens.background, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        backgroundColor: tokens.textPrimary,
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
    final tokens = context.tokens;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (!_goBack()) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: tokens.background,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),
              ..._buildBodySlivers(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final tokens = context.tokens;
    const iconSz = 20.0;
    final showNav = _searchActive || _currentPath != null || _activeCategory != null;

    return SliverAppBar(
      backgroundColor: tokens.surface1,
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
            icon: Icon(LucideIcons.chevronLeft, size: iconSz, color: tokens.textPrimary),
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
          Text('CMD>', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              autofocus: true,
              style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 12, letterSpacing: 1),
              cursorColor: tokens.textPrimary,
              decoration: InputDecoration(
                hintText: 'SEARCH QUERY...',
                hintStyle: TextStyle(color: tokens.textMuted),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ],
      )
          : Padding(
        padding: EdgeInsets.only(left: showNav ? 0 : _textPad),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _title.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                    color: tokens.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4
                ),
              ),
            ),

          ],
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
                icon: Icon(LucideIcons.search, size: iconSz, color: tokens.textSecondary),
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
                icon: Icon(LucideIcons.x, size: iconSz, color: tokens.textMuted),
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
                icon: Icon(_isListView ? LucideIcons.layoutGrid : LucideIcons.list, size: iconSz, color: tokens.textSecondary),
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
              icon: Icon(LucideIcons.download, size: iconSz, color: tokens.textSecondary),
              onPressed: () => showDownloadsSheet(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
      ),
    );
  }

  List<Widget> _buildBodySlivers(BuildContext context) {
    final tokens = context.tokens;
    if (_currentPath == null && _activeCategory == null && !_isLoading) {
      return _buildHomeSlivers(context);
    }
    if (_isLoading) return _buildSkeletonSlivers(context);
    if (_error != null) return _buildErrorSlivers(context);

    if (_activeCategory == 'live') {
      if (_stations.isEmpty) return _buildEmptySlivers(context);
      return [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))), color: tokens.border.withValues(alpha: 0.15)),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: 3.5,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
              ),
              itemCount: _stations.length,
              itemBuilder: (_, i) => _MobileStationCard(station: _stations[i], onTap: () => _tuneIn(_stations[i])),
            ),
          ),
        ),
      ];
    }

    final items = _displayItems;
    if (items.isEmpty) return _buildEmptySlivers(context);

    return _isListView ? _buildListSlivers(items) : _buildGridSlivers(context, items);
  }

  // ── Home View Slivers ─────────────────────────────────────────────────────

  List<Widget> _buildHomeSlivers(BuildContext context) {
    final tokens = context.tokens;
    return [
      // Storage Analysis Card
      SliverToBoxAdapter(child: _buildStorageCard(context)),
      // Categories Grid (3 Columns)
      SliverToBoxAdapter(
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))), color: tokens.border.withValues(alpha: 0.15)),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            children: [
              ..._kCategories.map((cat) => _BrutalistInteractiveCard(
                onTap: () => _openCategory(cat),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cat.icon, color: tokens.textPrimary, size: 22),
                    const SizedBox(height: 7),
                    Text(
                      cat.label,
                      style: GoogleFonts.dmMono(color: tokens.textSecondary, fontSize: 9, letterSpacing: 1),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )),
              _BrutalistInteractiveCard(
                onTap: () => _openCategory(const _Category(id: 'live', label: 'LIVE', icon: LucideIcons.radio)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.radio, color: _stations.isNotEmpty ? tokens.accent : tokens.textPrimary, size: 22),
                    const SizedBox(height: 7),
                    Text(
                      'LIVE',
                      style: GoogleFonts.dmMono(color: _stations.isNotEmpty ? tokens.accent : tokens.textSecondary, fontSize: 9, letterSpacing: 1),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              _BrutalistInteractiveCard(
                onTap: () {
                  _navStack.add('');
                  _loadPath('');
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.terminal, color: tokens.textPrimary, size: 22),
                    const SizedBox(height: 7),
                    Text(
                      'DIRECTORY',
                      style: GoogleFonts.dmMono(color: tokens.textSecondary, fontSize: 9, letterSpacing: 1),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }

  Widget _buildStorageCard(BuildContext context) {
    final tokens = context.tokens;
    final imgs = _allItems.where((i) => i.type == SFileType.image).length;
    final vids = _allItems.where((i) => i.type == SFileType.video).length;
    final auds = _allItems.where((i) => i.type == SFileType.audio).length;
    final total = _allItems.length;
    final other = total - imgs - vids - auds;

    Widget legend(String label, int count, Color color) => Row(
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: GoogleFonts.dmMono(color: tokens.textSecondary, fontSize: 10))),
          Text(count.toString(), style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
        ],
      );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STORAGE ANALYSIS', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Icon(LucideIcons.hardDrive, color: tokens.textMuted, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          if (total > 0)
            SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (vids > 0) Expanded(flex: vids, child: Container(color: tokens.textPrimary)),
                  if (imgs > 0) Expanded(flex: imgs, child: Container(color: tokens.textSecondary)),
                  if (auds > 0) Expanded(flex: auds, child: Container(color: tokens.textMuted)),
                  if (other > 0) Expanded(flex: other, child: Container(color: tokens.surface2)),
                ],
              ),
            )
          else
            Container(height: 12, color: tokens.surface2),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Column(children: [legend('VIDEOS', vids, tokens.textPrimary), const SizedBox(height: 8), legend('IMAGES', imgs, tokens.textSecondary)])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [legend('AUDIO', auds, tokens.textMuted), const SizedBox(height: 8), legend('OTHER', other, tokens.surface2)])),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: tokens.border.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL INDEXED FILES', style: GoogleFonts.dmMono(fontSize: 10, color: tokens.textMuted, letterSpacing: 1)),
              Text('$total', style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Skeleton & State Slivers ──────────────────────────────────────────────

  List<Widget> _buildSkeletonSlivers(BuildContext context) {
    final tokens = context.tokens;
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, i) => Container(
            height: 60,
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)), top: i == 0 ? BorderSide(color: tokens.border.withValues(alpha: 0.15)) : BorderSide.none),
                color: tokens.surface1
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(width: 40, height: 40, color: tokens.surface2),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 11, width: double.infinity, color: tokens.surface2),
                      const SizedBox(height: 6),
                      Container(width: 80, height: 9, color: tokens.surface2),
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

  List<Widget> _buildEmptySlivers(BuildContext context) {
    final tokens = context.tokens;
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
            decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15), style: BorderStyle.solid)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.folderOpen, size: 48, color: tokens.textMuted),
                const SizedBox(height: 14),
                Text('DIRECTORY EMPTY', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 4)),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildErrorSlivers(BuildContext context) {
    final tokens = context.tokens;
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
            decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15), style: BorderStyle.solid)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.alertTriangle, size: 48, color: tokens.textMuted),
                const SizedBox(height: 14),
                Text('CONNECTION FAILED', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text((_error ?? 'UNKNOWN ERROR').toUpperCase(), style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _currentPath != null ? _loadPath(_currentPath!) : _loadHome(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: tokens.textPrimary)),
                    child: Text('RETRY', style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
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

  List<Widget> _buildListSlivers(List<SFileItem> items) => [
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

  List<Widget> _buildGridSlivers(BuildContext context, List<SFileItem> items) {
    final dirs = items.where((i) => i.isDirectory).toList();
    final files = items.where((i) => !i.isDirectory).toList();

    // Exact match: 3 crossAxisCount brutalist layout
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      childAspectRatio: 0.8,
      crossAxisSpacing: 1,
      mainAxisSpacing: 1,
    );

    return [
      if (dirs.isNotEmpty) ...[
        SliverPadding(
          padding: EdgeInsets.zero,
          sliver: SliverGrid(
            gridDelegate: gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (_, i) => _FileGridCard(item: dirs[i], vm: _vm, onTap: () => _openItem(dirs[i]), onDownload: () => _triggerDownload(dirs[i])),
              childCount: dirs.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],

      if (files.isNotEmpty) ...[
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 100),
          sliver: SliverGrid(
            gridDelegate: gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (_, i) => _FileGridCard(item: files[i], vm: _vm, onTap: () => _openItem(files[i]), onDownload: () => _triggerDownload(files[i])),
              childCount: files.length,
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

  const _BrutalistInteractiveCard({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_BrutalistInteractiveCard> createState() => _BrutalistInteractiveCardState();
}

class _BrutalistInteractiveCardState extends State<_BrutalistInteractiveCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isFocused = true),
      onTapUp: (_) {
        setState(() => _isFocused = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isFocused = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _isFocused ? tokens.textPrimary.withValues(alpha: 0.1) : tokens.background,
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

  const _FileListTile({required this.item, required this.vm, required this.isFirst, required this.onTap, required this.onDownload});
  final SFileItem item;
  final ClientViewModel vm;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  @override
  State<_FileListTile> createState() => _FileListTileState();
}

class _FileListTileState extends State<_FileListTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const iconBoxSz = 44.0;

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
          color: _isFocused ? tokens.textPrimary.withValues(alpha: 0.1) : tokens.surface1,
          border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)), top: widget.isFirst ? BorderSide(color: tokens.border.withValues(alpha: 0.15)) : BorderSide.none),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Icon / thumbnail
            if (thumbUrl != null)
              Container(
                width: iconBoxSz,
                height: iconBoxSz,
                decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15)), color: tokens.background),
                child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.icon),
              )
            else
              Container(
                width: iconBoxSz,
                height: iconBoxSz,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  border: Border.all(color: tokens.border.withValues(alpha: 0.15)),
                ),
                child: Icon(widget.item.icon, color: tokens.textSecondary, size: iconBoxSz * 0.45),
              ),
            const SizedBox(width: 10),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (widget.item.isDirectory)
                        Text('${widget.item.itemCount} ITEMS', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 1))
                      else if (widget.item.sizeLabel.isNotEmpty) ...[
                        Text(widget.item.sizeLabel, style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 1)),
                        Text('  ///  ', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 1)),
                      ],
                      Text(widget.item.typeLabel, style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
            ),
            // Action button
            if (widget.item.isDirectory)
              Icon(LucideIcons.chevronRight, color: tokens.textMuted, size: 15)
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
                    icon: Icon(LucideIcons.download, color: tokens.textPrimary, size: 20),
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

  const _FileGridCard({required this.item, required this.vm, required this.onTap, required this.onDownload});
  final SFileItem item;
  final ClientViewModel vm;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  @override
  State<_FileGridCard> createState() => _FileGridCardState();
}

class _FileGridCardState extends State<_FileGridCard> {
  final bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
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
        color: _isFocused || _isPressed ? tokens.textPrimary : tokens.surface2,
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
                      color: tokens.background,
                      child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.icon),
                    )
                  else
                    Container(
                      color: isDir ? tokens.surface1 : tokens.surface2,
                      child: Center(
                        child: Icon(widget.item.icon, color: isDir ? tokens.textPrimary : tokens.textMuted, size: isDir ? 32 : 24),
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: tokens.surface1,
                  border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmMono(
                          color: _isFocused || _isPressed ? tokens.background : tokens.textSecondary,
                          fontSize: 9,
                          fontWeight: (_isFocused || _isPressed) ? FontWeight.bold : FontWeight.normal,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    // Bottom-Right Download Button (Files Only)
                    if (!isDir)
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
                          child: GestureDetector(
                            onTap: widget.onDownload,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15)), color: tokens.background),
                              child: Icon(LucideIcons.download, color: tokens.textPrimary, size: 12),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE STATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MobileStationCard extends StatefulWidget {

  const _MobileStationCard({required this.station, required this.onTap});
  final BroadcastStation station;
  final VoidCallback onTap;

  @override
  State<_MobileStationCard> createState() => _MobileStationCardState();
}

class _MobileStationCardState extends State<_MobileStationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final nowPlaying = widget.station.nowPlaying;
    final title = widget.station.name.toUpperCase();
    final itemTitle = nowPlaying != null ? nowPlaying.item.title.toUpperCase() : 'AWAITING SIGNAL';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _pressed ? tokens.textPrimary.withValues(alpha: 0.1) : tokens.surface1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title, style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1), maxLines: 1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: tokens.textPrimary)),
                  child: Text('LIVE', style: GoogleFonts.dmMono(fontSize: 9, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STATUS // NOW PLAYING', style: GoogleFonts.dmMono(fontSize: 8, color: tokens.textMuted, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(itemTitle, style: GoogleFonts.dmMono(fontSize: 10, color: tokens.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
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

  const _SortMenuButton({required this.sortBy, required this.sortAsc, required this.onChanged});
  final String sortBy;
  final bool sortAsc;
  final void Function(String by, bool asc) onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return PopupMenuButton<String>(
      icon: Icon(LucideIcons.arrowDownWideNarrow, size: 20, color: tokens.textSecondary),
      color: tokens.surface1,
      shape: Border.all(color: tokens.border.withValues(alpha: 0.15)),
      onSelected: (v) => onChanged(v, v == sortBy ? !sortAsc : true),
      itemBuilder: (_) => [_sortItem(context, 'name', 'NAME'), _sortItem(context, 'size', 'SIZE'), _sortItem(context, 'type', 'TYPE')],
    );
  }

  PopupMenuItem<String> _sortItem(BuildContext context, String value, String label) {
    final tokens = context.tokens;
    final active = value == sortBy;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.dmMono(color: active ? tokens.textPrimary : tokens.textSecondary, fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.normal, letterSpacing: 1),
          ),
          const Spacer(),
          if (active) Icon(sortAsc ? LucideIcons.arrowUp : LucideIcons.arrowDown, size: 13, color: tokens.textPrimary),
        ],
      ),
    );
  }
}
