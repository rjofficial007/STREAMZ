// presentation/mobile/file_manager.dart
// ============================================================================
// STREAMZ — Mobile / Tablet File Manager
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

  bool _isListView = true;
  bool _searchActive = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  String _sortBy = 'name';
  bool _sortAsc = true;
  String? _activeCategory;
  String? _activeCategoryLabel;

  late ClientViewModel _vm;

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

  // ── Data ──────────────────────────────────────────────────────────────────

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
        case 'size':
          r = a.size.compareTo(b.size);
          break;
        case 'type':
          r = a.ext.compareTo(b.ext);
          break;
        default:
          r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
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

  void _triggerDownload(SFileItem item) {
    final mediaItem = MediaItem(id: item.path, title: item.name, duration: 0, type: item.mediaType, folder: 'Download');
    _vm.downloadMedia(item: mediaItem, isPathBased: item.isPathBased);
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

  List<SFileItem> get _displayItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = DS.isMobile(context);
    final hPad = Responsive.hPad(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (!_goBack()) Navigator.pop(context);
        }
      },
      child: AppScaffold(appBar: _buildAppBar(isMobile), body: _buildBody(isMobile, hPad)),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    final iconSz = isMobile ? 20.0 : 22.0;
    final showNav = _searchActive || _currentPath != null || _activeCategory != null;

    return AppBar(
      backgroundColor: DS.bg,
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
                  icon: Icon(LucideIcons.chevronLeft, size: iconSz),
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
          ? TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              autofocus: true,
              style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 13 : 14),
              decoration: const InputDecoration(
                hintText: 'SEARCH...',
                hintStyle: TextStyle(color: DS.textMuted),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            )
          : Text(
              _title.toUpperCase(),
              style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold, letterSpacing: 2),
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
                icon: Icon(LucideIcons.search, size: iconSz),
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
                icon: Icon(LucideIcons.x, size: iconSz),
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
                icon: Icon(_isListView ? LucideIcons.layoutGrid : LucideIcons.list, size: iconSz),
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
              icon: Icon(LucideIcons.download, size: iconSz),
              onPressed: () => showDownloadsSheet(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(bool isMobile, double hPad) {
    if (_currentPath == null && _activeCategory == null && !_isLoading) {
      return _buildHome(isMobile, hPad);
    }
    if (_isLoading) return _buildSkeleton(isMobile, hPad);
    if (_error != null) return _buildError(isMobile);

    final items = _displayItems;
    if (items.isEmpty) return _buildEmpty(isMobile);

    return _isListView ? _buildListView(items, isMobile, hPad) : _buildGridView(items, isMobile, hPad);
  }

  // ── Home ──────────────────────────────────────────────────────────────────

  Widget _buildHome(bool isMobile, double hPad) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, isMobile ? 16 : 24, hPad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QUICK ACCESS', style: AppTheme.theme.textTheme.labelSmall),
                SizedBox(height: isMobile ? 12 : 16),
                _buildCategoryGrid(isMobile),
                SizedBox(height: isMobile ? 24 : 36),
                Text('SYS STORAGE', style: AppTheme.theme.textTheme.labelSmall),
                SizedBox(height: isMobile ? 12 : 16),
                _buildStorageCard(isMobile),
                SizedBox(height: isMobile ? 12 : 16),
                _buildRootButton(isMobile),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(bool isMobile) {
    final extent = Responsive.value<double>(context, mobile: 90, tablet: 110, desktop: 100);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: extent, childAspectRatio: 0.9, crossAxisSpacing: isMobile ? 8 : 12, mainAxisSpacing: isMobile ? 8 : 12),
      itemCount: _kCategories.length,
      itemBuilder: (_, i) => AppCard(
        onTap: () => _openCategory(_kCategories[i]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_kCategories[i].icon, color: DS.textPrimary, size: isMobile ? 22 : 26),
            SizedBox(height: isMobile ? 7 : 10),
            Text(
              _kCategories[i].label,
              style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: isMobile ? 9 : 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
          Expanded(child: Text(label, style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 10))),
          Text(
            count.toString(),
            style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      );
    }

    return BrutalistBlock(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STORAGE ANALYSIS', style: AppTheme.theme.textTheme.labelMedium),
              const Icon(LucideIcons.pieChart, color: DS.textMuted, size: 20),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(
                height: isMobile ? 12 : 16,
                child: Row(
                  children: [
                    if (vids > 0)
                      Expanded(
                        flex: vids,
                        child: Container(color: DS.accent),
                      ),
                    if (imgs > 0)
                      Expanded(
                        flex: imgs,
                        child: Container(color: Colors.white70),
                      ),
                    if (auds > 0)
                      Expanded(
                        flex: auds,
                        child: Container(color: Colors.white30),
                      ),
                    if (other > 0)
                      Expanded(
                        flex: other,
                        child: Container(color: DS.surface3),
                      ),
                  ],
                ),
              ),
            )
          else
            Container(height: isMobile ? 12 : 16, color: DS.surface3),
          SizedBox(height: isMobile ? 20 : 24),
          Row(
            children: [
              Expanded(child: Column(children: [legend('VIDEOS', vids, DS.accent), const SizedBox(height: 8), legend('IMAGES', imgs, Colors.white70)])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [legend('AUDIO', auds, Colors.white30), const SizedBox(height: 8), legend('OTHER', other, DS.surface3)])),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Container(height: 1, color: DS.borderDefault),
          SizedBox(height: isMobile ? 12 : 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL INDEXED FILES', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: DS.textMuted)),
              Text(
                '$total',
                style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.bold, color: DS.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRootButton(bool isMobile) {
    return AppCard(
      onTap: () {
        _navStack.add('');
        _loadPath('');
      },
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Row(
          children: [
            Icon(LucideIcons.hardDrive, size: isMobile ? 24 : 28, color: DS.textPrimary),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ROOT DIRECTORY', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 12 : 13)),
                  const SizedBox(height: 3),
                  Text('${_allItems.length} FILES INDEXED', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: isMobile ? 9 : 10)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: DS.textMuted, size: isMobile ? 16 : 18),
          ],
        ),
      ),
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────

  Widget _buildSkeleton(bool isMobile, double hPad) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 40),
      itemCount: 12,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          height: isMobile ? 60 : 72,
          color: DS.surface1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SkeletonBox(width: isMobile ? 40 : 52, height: isMobile ? 40 : 52),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [SkeletonBox(height: 11), SizedBox(height: 6), SkeletonBox(width: 80, height: 9)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── List view ─────────────────────────────────────────────────────────────

  Widget _buildListView(List<SFileItem> items, bool isMobile, double hPad) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, top: 8),
      itemCount: items.length,
      itemBuilder: (_, i) => _FileListTile(item: items[i], hPad: hPad, vm: _vm, onTap: () => _openItem(items[i]), onDownload: () => _triggerDownload(items[i])),
    );
  }

  // ── Grid view ─────────────────────────────────────────────────────────────

  Widget _buildGridView(List<SFileItem> items, bool isMobile, double hPad) {
    final dirs = items.where((i) => i.isDirectory).toList();
    final files = items.where((i) => !i.isDirectory).toList();
    final extent = Responsive.value<double>(context, mobile: 110, tablet: 150, desktop: 140);
    final spacing = Responsive.value<double>(context, mobile: 0, tablet: 0, desktop: 0);
    final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: extent, childAspectRatio: 0.85, crossAxisSpacing: spacing, mainAxisSpacing: spacing);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: isMobile ? 8 : 16)),
        if (dirs.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, isMobile ? 12 : 20, hPad, 0),
            sliver: SliverToBoxAdapter(child: Text('DIRECTORIES', style: AppTheme.theme.textTheme.labelSmall)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, isMobile ? 16 : 24),
            sliver: SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (_, i) => _FileGridCard(item: dirs[i], vm: _vm, onTap: () => _openItem(dirs[i]), onDownload: () => _triggerDownload(dirs[i])),
                childCount: dirs.length,
              ),
            ),
          ),
        ],
        if (files.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
            sliver: SliverToBoxAdapter(child: Text('FILES', style: AppTheme.theme.textTheme.labelSmall)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 100),
            sliver: SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (_, i) => _FileGridCard(item: files[i], vm: _vm, onTap: () => _openItem(files[i]), onDownload: () => _triggerDownload(files[i])),
                childCount: files.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildEmpty(bool isMobile) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.folderOpen, size: isMobile ? 48 : 60, color: DS.textMuted),
        SizedBox(height: isMobile ? 14 : 20),
        Text('DIRECTORY EMPTY', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 12 : 13)),
      ],
    ),
  );

  Widget _buildError(bool isMobile) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.alertTriangle, size: isMobile ? 48 : 60, color: DS.textMuted),
        SizedBox(height: isMobile ? 14 : 20),
        Text('CONNECTION FAILED', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: isMobile ? 12 : 13)),
        const SizedBox(height: 6),
        Text(_error ?? 'UNKNOWN ERROR', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: isMobile ? 10 : 11)),
        SizedBox(height: isMobile ? 24 : 32),
        SizedBox(
          width: 140,
          child: AppButton(label: 'RETRY', height: isMobile ? 44 : 52, onTap: () => _currentPath != null ? _loadPath(_currentPath!) : _loadHome()),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FILE LIST TILE
// ─────────────────────────────────────────────────────────────────────────────

class _FileListTile extends StatelessWidget {
  final SFileItem item;
  final double hPad;
  final ClientViewModel vm;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _FileListTile({required this.item, required this.hPad, required this.vm, required this.onTap, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final isMobile = DS.isMobile(context);
    final iconBoxSz = isMobile ? 44.0 : 52.0;
    final nameFontSz = isMobile ? 11.5 : 13.0;
    final metaFontSz = isMobile ? 9.5 : 10.5;

    String? thumbUrl;
    if (item.isPlayable) {
      if (item.isPathBased) {
        thumbUrl = item.type == SFileType.image ? vm.fileUrl(item.path) : vm.thumbnailUrlForPath(item.path);
      } else {
        thumbUrl = vm.thumbnailUrl(item.path);
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: isMobile ? 2 : 3),
      child: AppCard(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 8 : 11),
          child: Row(
            children: [
              // Icon / thumbnail
              if (thumbUrl != null)
                Container(
                  width: iconBoxSz,
                  height: iconBoxSz,
                  decoration: BoxDecoration(border: Border.all(color: DS.borderDefault)),
                  child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: item.icon),
                )
              else
                Container(
                  width: iconBoxSz,
                  height: iconBoxSz,
                  decoration: BoxDecoration(
                    color: DS.surface1,
                    border: Border.all(color: DS.borderDefault),
                  ),
                  child: Icon(item.icon, color: DS.textPrimary, size: iconBoxSz * 0.45),
                ),
              SizedBox(width: isMobile ? 10 : 14),
              // Name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: nameFontSz),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.isDirectory)
                          Text('${item.itemCount} ITEMS', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: metaFontSz))
                        else if (item.sizeLabel.isNotEmpty) ...[
                          Text(item.sizeLabel, style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: metaFontSz)),
                          Text('  ///  ', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: metaFontSz)),
                        ],
                        Text(item.typeLabel, style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: metaFontSz)),
                      ],
                    ),
                  ],
                ),
              ),
              // Action button
              if (item.isDirectory)
                Icon(LucideIcons.chevronRight, color: DS.textMuted, size: isMobile ? 15 : 17)
              else
                Actions(
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        onDownload();
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    onKeyEvent: (_, ev) => handleTVSelectKey(ev, onDownload),
                    child: IconButton(
                      icon: Icon(LucideIcons.download, color: DS.accent, size: isMobile ? 20 : 22),
                      onPressed: onDownload,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILE GRID CARD
// ─────────────────────────────────────────────────────────────────────────────

class _FileGridCard extends StatelessWidget {
  final SFileItem item;
  final ClientViewModel vm;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _FileGridCard({required this.item, required this.vm, required this.onTap, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final isMobile = DS.isMobile(context);
    final isDir = item.isDirectory;

    String? thumbUrl;
    if (item.isPlayable) {
      if (item.isPathBased) {
        thumbUrl = item.type == SFileType.image ? vm.fileUrl(item.path) : vm.thumbnailUrlForPath(item.path);
      } else {
        thumbUrl = vm.thumbnailUrl(item.path);
      }
    }

    return AppCard(
      onTap: onTap,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: thumbUrl != null
                    ? NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: item.icon)
                    : Container(
                        color: isDir ? DS.surface3 : DS.surface1,
                        child: Center(
                          child: Icon(item.icon, color: isDir ? DS.accent : DS.textMuted, size: isMobile ? (isDir ? 42 : 28) : (isDir ? 56 : 36)),
                        ),
                      ),
              ),
              Container(height: 1, color: DS.borderDefault),
              Container(
                color: DS.surface1,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 7 : 10, vertical: isMobile ? 6 : 8),
                child: Text(
                  item.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: isMobile ? 9 : 10),
                ),
              ),
            ],
          ),

          // Badge
          Positioned(
            top: DS.s4,
            left: DS.s4,
            child: StatusBadge(label: isDir ? '${item.itemCount} ITEMS' : item.typeLabel),
          ),

          // Download button (files only)
          if (!isDir)
            Positioned(
              bottom: 0,
              right: 0,
              child: Actions(
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      onDownload();
                      return null;
                    },
                  ),
                },
                child: Focus(
                  onKeyEvent: (_, ev) => handleTVSelectKey(ev, onDownload),
                  child: GestureDetector(
                    onTap: onDownload,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      color: DS.surface1.withValues(alpha: 0.8),
                      child: Icon(LucideIcons.download, color: DS.accent, size: isMobile ? 16 : 18),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
      icon: Icon(LucideIcons.arrowDownWideNarrow, size: isMobile ? 20 : 22),
      color: DS.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: DS.borderDefault),
      ),
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
            style: AppTheme.theme.textTheme.labelMedium?.copyWith(color: active ? DS.accent : DS.textPrimary, fontSize: isMobile ? 11 : 13),
          ),
          const Spacer(),
          if (active) Icon(sortAsc ? LucideIcons.arrowUp : LucideIcons.arrowDown, size: isMobile ? 13 : 15, color: DS.accent),
        ],
      ),
    );
  }
}
