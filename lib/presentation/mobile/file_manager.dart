// presentation/mobile/file_manager.dart
// ============================================================================
// STREAMZ — Mobile and Tablet File Manager
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/mobile/downloads_sheet.dart';
import 'package:streamz/presentation/player/player_screen.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
import 'package:streamz/presentation/shared/app_summary_components.dart';
import 'package:streamz/presentation/shared/file_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  const _Category({
    required this.id,
    required this.label,
    required this.icon,
    this.filterType,
  });
  final String id;
  final String label;
  final IconData icon;
  final SFileType? filterType;
}

const _kCategories = [
  _Category(id: 'recent', label: 'Recent', icon: LucideIcons.history),
  _Category(
    id: 'images',
    label: 'Images',
    icon: LucideIcons.image,
    filterType: SFileType.image,
  ),
  _Category(
    id: 'videos',
    label: 'Videos',
    icon: LucideIcons.film,
    filterType: SFileType.video,
  ),
  _Category(
    id: 'audio',
    label: 'Audio',
    icon: LucideIcons.activity,
    filterType: SFileType.audio,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SamsungFileManagerScreen extends StatefulWidget {
  const SamsungFileManagerScreen({super.key});

  @override
  State<SamsungFileManagerScreen> createState() =>
      _SamsungFileManagerScreenState();
}

class _SamsungFileManagerScreenState extends State<SamsungFileManagerScreen>
    with TickerProviderStateMixin {
  final List<String?> _navStack = [null];
  final ScrollController _scrollController = ScrollController();
  String? get _currentPath => _navStack.last;

  List<SFileItem> _items = [];
  List<SFileItem> _allItems = [];
  List<BroadcastStation> _stations = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _browseHasMore = false;
  int _browseOffset = 0;
  int _browseGeneration = 0;
  String? _loadedBrowsePath;
  String? _error;

  bool _isListView = false; // Defaulted to Grid View based on 3-column request
  bool _showAllRecent = false;
  bool _searchActive = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
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
    if (_activeCategory != null) return _activeCategoryLabel ?? 'Files';
    if (_currentPath == null || _currentPath!.isEmpty) return 'Files';
    final parts = _currentPath!.replaceAll(r'\', '/').split('/');
    return parts.where((s) => s.isNotEmpty).lastOrNull ?? 'Root';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onBrowseScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm = context.read<ClientViewModel>();
      _loadHome();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
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
    _allItems = media
        .map(
          (m) => SFileItem(
            name: m.title,
            path: m.id,
            isDirectory: false,
            size: 0,
            type: _parseType(m.type),
            isPathBased: false,
          ),
        )
        .toList();
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

  Future<void> _loadPath(String path, {String query = ''}) async {
    _searchDebounce?.cancel();
    final generation = ++_browseGeneration;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _browseHasMore = false;
      _browseOffset = 0;
      _loadedBrowsePath = path;
      _error = null;
      _searchActive = query.isNotEmpty;
      _searchQuery = query.toLowerCase();
      if (query.isEmpty) _searchCtrl.clear();
      _activeCategory = null;
    });
    try {
      final page = await _vm.browseRemotePage(
        path,
        offset: 0,
        query: query,
        sortBy: _sortBy,
        ascending: _sortAsc,
      );
      final items = page.items.map(SFileItem.fromJson).toList();
      if (mounted && generation == _browseGeneration) {
        setState(() {
          _items = items;
          _browseOffset = items.length;
          _browseHasMore = page.hasMore;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _onBrowseScroll());
      }
    } catch (e) {
      if (mounted && generation == _browseGeneration) {
        setState(() {
          _error = 'Connection failed. Check the server and try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onBrowseScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 400) {
      _loadMoreBrowseItems();
    }
  }

  Future<void> _loadMoreBrowseItems() async {
    final path = _loadedBrowsePath;
    if (!mounted || _isLoading || _isLoadingMore || !_browseHasMore || path == null) {
      return;
    }
    final generation = _browseGeneration;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _vm.browseRemotePage(
        path,
        offset: _browseOffset,
        query: _searchQuery,
        sortBy: _sortBy,
        ascending: _sortAsc,
      );
      if (!mounted || generation != _browseGeneration) return;
      setState(() {
        _items = [..._items, ...page.items.map(SFileItem.fromJson)];
        _browseOffset += page.items.length;
        _browseHasMore = page.hasMore;
        _isLoadingMore = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _onBrowseScroll());
    } catch (_) {
      if (mounted && generation == _browseGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  List<SFileItem> _sort(List<SFileItem> items) {
    final dirs = items.where((i) => i.isDirectory).toList();
    final files = items.where((i) => !i.isDirectory).toList();
    int cmp(SFileItem a, SFileItem b) {
      var r = 0;
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
    _searchDebounce?.cancel();
    setState(() {
      _activeCategory = cat.id;
      _activeCategoryLabel = cat.label;
      _loadedBrowsePath = null;
      _browseHasMore = false;
      _isLoadingMore = false;
      _showAllRecent = false;
      _isLoading = false;
      if (cat.id == 'live') {
        _items = []; // Stations are handled separately in _buildBodySlivers
      } else {
        _items = cat.id == 'recent'
            ? _sort(_allItems.take(50).toList())
            : (cat.filterType != null
                  ? _sort(
                      _allItems.where((i) => i.type == cat.filterType).toList(),
                    )
                  : []);
      }
    });
  }

  void _navigateTo(String path) {
    _navStack.add(path);
    _loadPath(path);
  }

  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      if (_loadedBrowsePath != null) {
        _loadPath(_loadedBrowsePath!);
      } else {
        setState(() => _searchQuery = '');
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final normalized = query.trim().toLowerCase();
      if (_loadedBrowsePath != null && _activeCategory == null) {
        _loadPath(_loadedBrowsePath!, query: normalized);
      } else {
        setState(() => _searchQuery = normalized);
      }
    });
  }

  void _clearSearchQuery() {
    _searchDebounce?.cancel();
    if (_loadedBrowsePath != null) {
      _loadPath(_loadedBrowsePath!);
    } else {
      setState(() => _searchQuery = '');
    }
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _searchActive = false;
      _searchQuery = '';
    });
    if (_loadedBrowsePath != null) _loadPath(_loadedBrowsePath!);
  }

  bool _goBack() {
    if (_searchActive) {
      _closeSearch();
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
    final playlist = playable
        .map(
          (i) => MediaItem(
            id: i.path,
            title: i.name,
            duration: 0,
            type: i.mediaType,
            folder: _title,
          ),
        )
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          items: playlist.isEmpty
              ? [
                  MediaItem(
                    id: item.path,
                    title: item.name,
                    duration: 0,
                    type: item.mediaType,
                    folder: _title,
                  ),
                ]
              : playlist,
          startIndex: idx >= 0 ? idx : 0,
          isPathBased: item.isPathBased,
        ),
      ),
    );
  }

  Future<void> _tuneIn(BroadcastStation station) async {
    final res = await _vm.joinStation(station.id);
    if (res != null && mounted) {
      unawaited(
        context.push(
          '/player',
          extra: {
            'items': res.playlist,
            'startIndex': res.itemIndex,
            'isPathBased': false,
            'startOffset': res.position,
          },
        ),
      );
    }
  }

  void _triggerDownload(SFileItem item) {
    final tokens = context.tokens;
    final mediaItem = MediaItem(
      id: item.path,
      title: item.name,
      duration: 0,
      type: item.mediaType,
      folder: 'Download',
    );
    _vm.downloadMedia(item: mediaItem, isPathBased: item.isPathBased);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Downloading ${item.name}',
          style: AppTextStyles.caption.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: tokens.surface3,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radius(12))),
      ),
    );
  }

  List<SFileItem> get _displayItems {
    if (_searchQuery.isEmpty) return _items;
    final query = _searchQuery;
    return _items
        .where((i) => i.name.toLowerCase().contains(query))
        .toList();
  }

  // ── Build Methods ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        if (!_goBack()) Navigator.pop(context);
      }
    },
    child: AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppSliverAppBar(context),
            ..._buildBodySlivers(
              context,
            ).map((sliver) => AppContentSliver(sliver: sliver)),
          ],
        ),
      ),
    ),
  );

  Widget _buildAppSliverAppBar(BuildContext context) {
    final tokens = context.tokens;
    const iconSz = 20.0;
    final showNav =
        _searchActive || _currentPath != null || _activeCategory != null;

    return AppSliverAppBar(
      floating: true,
      pinned: true,
      titleSpacing: 0,
      leading: showNav
          ? Actions(
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _searchActive ? _closeSearch() : _goBack();
                    return null;
                  },
                ),
              },
              child: Focus(
                onKeyEvent: (_, ev) => handleTVSelectKey(
                  ev,
                  _searchActive ? _closeSearch : _goBack,
                ),
                child: AppBackButton(
                  iconSize: iconSz,
                  onPressed: _searchActive ? _closeSearch : _goBack,
                ),
              ),
            )
          : null,
      automaticallyImplyLeading: false,
      title: _searchActive
          ? Row(
              children: [
                if (!showNav) SizedBox(width: _textPad),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    autofocus: true,
                    style: AppTextStyles.caption.copyWith(
                      color: tokens.textPrimary,
                      letterSpacing: 0.2,
                    ),
                    cursorColor: tokens.textPrimary,
                    decoration: InputDecoration(
                      hintText: 'Search media',
                      hintStyle: TextStyle(color: tokens.textMuted),
                      border: InputBorder.none,
                    ),
                    onChanged: _scheduleSearch,
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
                      _title,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: AppTextStyles.titleFontWeight,
                        letterSpacing: -0.2,
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
              onKeyEvent: (_, ev) => handleTVSelectKey(
                ev,
                () => setState(() => _searchActive = true),
              ),
              child: IconButton(
                icon: Icon(
                  LucideIcons.search,
                  size: iconSz,
                  color: tokens.textSecondary,
                ),
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
                  _clearSearchQuery();
                  return null;
                },
              ),
            },
            child: Focus(
              onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
                _searchCtrl.clear();
                _clearSearchQuery();
              }),
              child: IconButton(
                icon: Icon(
                  LucideIcons.x,
                  size: iconSz,
                  color: tokens.textMuted,
                ),
                onPressed: () {
                  _searchCtrl.clear();
                  _clearSearchQuery();
                },
              ),
            ),
          ),
        if (!_searchActive)
          _SortMenuButton(
            sortBy: _sortBy,
            sortAsc: _sortAsc,
            onChanged: (by, asc) {
              setState(() {
                _sortBy = by;
                _sortAsc = asc;
                if (_loadedBrowsePath == null) _items = _sort(_items);
              });
              final path = _loadedBrowsePath;
              if (path != null) {
                unawaited(
                  _loadPath(path, query: _searchQuery),
                );
              }
            },
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
              onKeyEvent: (_, ev) => handleTVSelectKey(
                ev,
                () => setState(() => _isListView = !_isListView),
              ),
              child: IconButton(
                icon: Icon(
                  _isListView ? LucideIcons.layoutGrid : LucideIcons.list,
                  size: iconSz,
                  color: tokens.textSecondary,
                ),
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
            onKeyEvent: (_, ev) =>
                handleTVSelectKey(ev, () => showDownloadsSheet(context)),
            child: IconButton(
              icon: Icon(
                LucideIcons.download,
                size: iconSz,
                color: tokens.textSecondary,
              ),
              onPressed: () => showDownloadsSheet(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  List<Widget> _buildBodySlivers(BuildContext context) {
    if (_isLoading) return _buildLoadingSlivers();
    if (_error != null) return _buildErrorSlivers();
    if (_currentPath == null && _activeCategory == null && !_isLoading) {
      return _buildHomeSlivers(context);
    }

    if (_activeCategory == 'live') {
      if (_stations.isEmpty) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppStateView(
              title: 'No live broadcasts',
              description: 'Active broadcasts from your network will appear here.',
              icon: LucideIcons.radioTower,
            ),
          ),
        ];
      }
      return [
        const SliverToBoxAdapter(child: SizedBox(height: DS.s8)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final station = _stations[index];
              return AppListTileCard(
                title: station.name,
                subtitle: station.nowPlaying == null
                    ? 'Waiting for a track'
                    : 'Now playing · ${station.nowPlaying!.item.title}',
                icon: LucideIcons.radio,
                onTap: () => _tuneIn(station),
              );
            },
            childCount: _stations.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: DS.s24)),
      ];
    }

    final items = _displayItems;
    if (items.isEmpty) return _buildEmptySlivers();

    final slivers = _isListView
        ? _buildListSlivers(items)
        : _buildGridSlivers(context, items);
    if (_browseHasMore || _isLoadingMore) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DS.s16,
              DS.s16,
              DS.s16,
              DS.s32,
            ),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator(
                      semanticsLabel: 'Loading more files',
                    )
                  : TextButton.icon(
                      onPressed: _loadMoreBrowseItems,
                      icon: const Icon(LucideIcons.chevronDown),
                      label: const Text('Load more files'),
                    ),
            ),
          ),
        ),
      );
    }
    if (_activeCategory == 'recent' &&
        _searchQuery.isEmpty &&
        _allItems.length > 50) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DS.s16,
              DS.s8,
              DS.s16,
              DS.s24,
            ),
            child: Column(
              children: [
                Text(
                  _showAllRecent
                      ? 'All ${_allItems.length} items shown'
                      : 'Showing 50 of ${_allItems.length} items',
                  style: AppTextStyles.caption.copyWith(
                    color: context.tokens.textMuted,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _showAllRecent = !_showAllRecent;
                    _items = _sort(
                      _showAllRecent ? _allItems : _allItems.take(50).toList(),
                    );
                  }),
                  icon: Icon(
                    _showAllRecent
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                  ),
                  label: Text(
                    _showAllRecent ? 'Show 50 items' : 'Show all items',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  // ── Home View Slivers ─────────────────────────────────────────────────────

  List<Widget> _buildHomeSlivers(BuildContext context) => [
      // Storage Analysis Card
      SliverToBoxAdapter(child: _buildStorageCard(context)),
      // Category actions share the responsive, focusable app action grid.
      SliverToBoxAdapter(
        child: AppActionGrid(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s16,
            vertical: DS.s12,
          ),
          minTileWidth: 100,
          maxColumns: 3,
          children: [
            ..._kCategories.map(
              (cat) => AppActionCard(
                label: cat.label,
                icon: cat.icon,
                onTap: () => _openCategory(cat),
              ),
            ),
            AppActionCard(
              label: 'Live streams',
              icon: LucideIcons.radio,
              isActive: _stations.isNotEmpty,
              onTap: () => _openCategory(
                const _Category(
                  id: 'live',
                  label: 'Live streams',
                  icon: LucideIcons.radio,
                ),
              ),
            ),
            AppActionCard(
              label: 'Browse folders',
              icon: LucideIcons.folderOpen,
              onTap: () {
                _navStack.add('');
                _loadPath('');
              },
            ),
          ],
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
  ];

  Widget _buildStorageCard(BuildContext context) {
    final tokens = context.tokens;
    final total = _allItems.length;
    var imgs = 0;
    var vids = 0;
    var auds = 0;
    for (final item in _allItems) {
      switch (item.type) {
        case SFileType.image:
          imgs++;
        case SFileType.video:
          vids++;
        case SFileType.audio:
          auds++;
        default:
          break;
      }
    }
    final other = total - imgs - vids - auds;

    Widget legend(String label, int count, Color color) => AppSummaryLegend(
      label: label,
      value: count.toString(),
      markerColor: color,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DS.radius(20)),
        border: Border.all(color: tokens.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Storage overview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: AppTextStyles.titleFontWeight,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: DS.s12),
              Icon(LucideIcons.hardDrive, color: tokens.textMuted, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          if (total > 0)
            SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (vids > 0)
                    Expanded(
                      flex: vids,
                      child: Container(color: tokens.textPrimary),
                    ),
                  if (imgs > 0)
                    Expanded(
                      flex: imgs,
                      child: Container(color: tokens.textSecondary),
                    ),
                  if (auds > 0)
                    Expanded(
                      flex: auds,
                      child: Container(color: tokens.textMuted),
                    ),
                  if (other > 0)
                    Expanded(
                      flex: other,
                      child: Container(color: tokens.surface2),
                    ),
                ],
              ),
            )
          else
            Container(height: 12, color: tokens.surface2),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    legend('Videos', vids, tokens.textPrimary),
                    const SizedBox(height: 8),
                    legend('Images', imgs, tokens.textSecondary),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    legend('Audio', auds, tokens.textMuted),
                    const SizedBox(height: 8),
                    legend('Other', other, tokens.surface2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: tokens.border.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Media items',
                style: AppTextStyles.caption.copyWith(
                  color: tokens.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                '$total',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Skeleton & State Slivers ──────────────────────────────────────────────

  List<Widget> _buildLoadingSlivers() => const [
    AppStateSliver(
      state: AppStateView(
        kind: AppStateKind.loading,
        title: 'Loading media library',
      ),
    ),
  ];

  List<Widget> _buildEmptySlivers() => [
    const AppStateSliver(
      state: AppStateView(
        title: 'Directory empty',
        icon: LucideIcons.folderOpen,
      ),
    ),
  ];

  List<Widget> _buildErrorSlivers() => [
    AppStateSliver(
      state: AppStateView(
        kind: AppStateKind.error,
        title: 'Connection failed',
        description: _error ?? 'Unknown error',
        icon: LucideIcons.alertTriangle,
        actionLabel: 'Retry',
        onAction: () =>
            _currentPath != null ? _loadPath(_currentPath!) : _loadHome(),
      ),
    ),
  ];

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
            onDownload: () => _triggerDownload(items[i]),
          ),
          childCount: items.length,
        ),
      ),
    ),
  ];

  List<Widget> _buildGridSlivers(BuildContext context, List<SFileItem> items) {
    final dirs = items.where((i) => i.isDirectory).toList();
    final files = items.where((i) => !i.isDirectory).toList();

    final availableWidth = MediaQuery.sizeOf(context).width - 2 * DS.s16;
    final columns = DS.responsiveColumns(
      context,
      availableWidth: availableWidth,
      spacing: DS.s12,
      minTileWidth: 124,
      maxColumns: 3,
    );
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      childAspectRatio: 0.75,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );

    return [
      if (dirs.isNotEmpty) ...[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (_, i) => _FileGridCard(
                item: dirs[i],
                vm: _vm,
                onTap: () => _openItem(dirs[i]),
                onDownload: () => _triggerDownload(dirs[i]),
              ),
              childCount: dirs.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],

      if (files.isNotEmpty) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverGrid(
            gridDelegate: gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (_, i) => _FileGridCard(
                item: files[i],
                vm: _vm,
                onTap: () => _openItem(files[i]),
                onDownload: () => _triggerDownload(files[i]),
              ),
              childCount: files.length,
            ),
          ),
        ),
      ],
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILE LIST TILE
// ─────────────────────────────────────────────────────────────────────────────

class _FileListTile extends StatelessWidget {
  const _FileListTile({
    required this.item,
    required this.vm,
    required this.isFirst,
    required this.onTap,
    required this.onDownload,
  });
  final SFileItem item;
  final ClientViewModel vm;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const iconBoxSz = 44.0;
    final metadata = item.cardMetadata;

    String? thumbUrl;
    if (item.isPlayable) {
      if (item.isPathBased) {
        thumbUrl = item.type == SFileType.image
            ? vm.fileUrl(item.path)
            : vm.thumbnailUrlForPath(item.path);
      } else {
        thumbUrl = vm.thumbnailUrl(item.path);
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, isFirst ? 12 : 6, 16, 6),
      child: AppCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Icon / thumbnail
              if (thumbUrl != null)
                Container(
                  width: iconBoxSz,
                  height: iconBoxSz,
                  decoration: BoxDecoration(
                    color: tokens.background,
                    borderRadius: BorderRadius.circular(DS.radius(10)),
                    border: Border.all(
                      color: tokens.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: NetworkImageFade(
                    url: thumbUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: item.icon,
                  ),
                )
              else
                Container(
                  width: iconBoxSz,
                  height: iconBoxSz,
                  decoration: BoxDecoration(
                    color: tokens.surface2,
                    borderRadius: BorderRadius.circular(DS.radius(10)),
                    border: Border.all(
                      color: tokens.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    color: tokens.textSecondary,
                    size: iconBoxSz * 0.45,
                  ),
                ),
              const SizedBox(width: 10),
              // Name and metadata adapt to narrow screens and text scaling.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metadata,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Download actions remain separate from opening the row.
              if (item.isDirectory)
                Icon(
                  LucideIcons.chevronRight,
                  color: tokens.textMuted,
                  size: 15,
                )
              else
                IconButton(
                  tooltip: 'Download ${item.name}',
                  icon: Icon(
                    LucideIcons.download,
                    color: tokens.textPrimary,
                    size: 20,
                  ),
                  onPressed: onDownload,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
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
// FILE GRID CARD with square artwork and a compact metadata footer.
// ─────────────────────────────────────────────────────────────────────────────

class _FileGridCard extends StatelessWidget {
  const _FileGridCard({
    required this.item,
    required this.vm,
    required this.onTap,
    required this.onDownload,
  });
  final SFileItem item;
  final ClientViewModel vm;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDir = item.isDirectory;

    String? thumbUrl;
    if (item.isPlayable) {
      if (item.isPathBased) {
        thumbUrl = item.type == SFileType.image
            ? vm.fileUrl(item.path)
            : vm.thumbnailUrlForPath(item.path);
      } else {
        thumbUrl = vm.thumbnailUrl(item.path);
      }
    }

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poster area keeps the title clean while exposing a large download target.
          Expanded(
            flex: 75,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbUrl != null)
                  Container(
                    color: tokens.background,
                    child: NetworkImageFade(
                      url: thumbUrl,
                      fit: BoxFit.cover,
                      fallbackIcon: item.icon,
                    ),
                  )
                else
                  Container(
                    color: isDir ? tokens.surface1 : tokens.surface2,
                    child: Center(
                      child: Icon(
                        item.icon,
                        color: isDir ? tokens.textPrimary : tokens.textMuted,
                        size: isDir ? 32 : 24,
                      ),
                    ),
                  ),
                if (!isDir)
                  Positioned(
                    right: DS.s8,
                    bottom: DS.s8,
                    child: IconButton(
                      tooltip: 'Download ${item.name}',
                      onPressed: onDownload,
                      style: IconButton.styleFrom(
                        backgroundColor: tokens.surface2.withValues(
                          alpha: 0.94,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: Icon(
                        LucideIcons.download,
                        color: tokens.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // A square artwork area with a compact two-line info footer.
          Expanded(
            flex: 25,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: tokens.surface1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    item.cardMetadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: tokens.textMuted,
                      fontSize: 10,
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

// ─────────────────────────────────────────────────────────────────────────────
// SORT MENU
// ─────────────────────────────────────────────────────────────────────────────

class _SortMenuButton extends StatelessWidget {
  const _SortMenuButton({
    required this.sortBy,
    required this.sortAsc,
    required this.onChanged,
  });
  final String sortBy;
  final bool sortAsc;
  final void Function(String by, bool asc) onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return PopupMenuButton<String>(
      icon: Icon(
        LucideIcons.arrowDownWideNarrow,
        size: 20,
        color: tokens.textSecondary,
      ),
      color: tokens.surface1,
      shape: Border.all(color: tokens.border.withValues(alpha: 0.15)),
      onSelected: (v) => onChanged(v, v == sortBy ? !sortAsc : true),
      itemBuilder: (_) => [
        _sortItem(context, 'name', 'Name'),
        _sortItem(context, 'size', 'Size'),
        _sortItem(context, 'type', 'Type'),
      ],
    );
  }

  PopupMenuItem<String> _sortItem(
    BuildContext context,
    String value,
    String label,
  ) {
    final tokens = context.tokens;
    final active = value == sortBy;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: active ? tokens.textPrimary : tokens.textSecondary,
              fontWeight: active ? FontWeight.w500 : FontWeight.normal,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (active)
            Icon(
              sortAsc ? LucideIcons.arrowUp : LucideIcons.arrowDown,
              size: 13,
              color: tokens.textPrimary,
            ),
        ],
      ),
    );
  }
}
