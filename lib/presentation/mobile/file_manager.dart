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
  _Category(id: 'recent', label: 'RECENT', icon: LucideIcons.history),
  _Category(
    id: 'images',
    label: 'IMAGES',
    icon: LucideIcons.image,
    filterType: SFileType.image,
  ),
  _Category(
    id: 'videos',
    label: 'VIDEOS',
    icon: LucideIcons.film,
    filterType: SFileType.video,
  ),
  _Category(
    id: 'audio',
    label: 'AUDIO',
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
          'DOWNLOADING ${item.name.toUpperCase()}',
          style: AppTextStyles.caption.copyWith(
            color: tokens.background,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: tokens.textPrimary,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radius(12))),
      ),
    );
  }

  List<SFileItem> get _displayItems {
    if (_searchQuery.isEmpty) return _items;
    return _items
        .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
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
                child: AppBackButton(
                  iconSize: iconSz,
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
                Text(
                  'CMD>',
                  style: AppTextStyles.caption.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
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
                      style: AppTextStyles.titleLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: AppTextStyles.titleFontWeight,
                        letterSpacing: 0.8,
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
                icon: Icon(
                  LucideIcons.x,
                  size: iconSz,
                  color: tokens.textMuted,
                ),
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
    if (_isLoading) return _buildSkeletonSlivers(context);
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

    return _isListView
        ? _buildListSlivers(items)
        : _buildGridSlivers(context, items);
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
              label: 'LIVE',
              icon: LucideIcons.radio,
              isActive: _stations.isNotEmpty,
              onTap: () => _openCategory(
                const _Category(
                  id: 'live',
                  label: 'LIVE',
                  icon: LucideIcons.radio,
                ),
              ),
            ),
            AppActionCard(
              label: 'DIRECTORY',
              icon: LucideIcons.terminal,
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

    Widget legend(String label, int count, Color color) => Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: tokens.textSecondary),
          ),
        ),
        Text(
          count.toString(),
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
          ),
        ),
      ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STORAGE ANALYSIS',
                style: AppTextStyles.title.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: AppTextStyles.titleFontWeight,
                  letterSpacing: 0.2,
                ),
              ),
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
                    legend('VIDEOS', vids, tokens.textPrimary),
                    const SizedBox(height: 8),
                    legend('IMAGES', imgs, tokens.textSecondary),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    legend('AUDIO', auds, tokens.textMuted),
                    const SizedBox(height: 8),
                    legend('OTHER', other, tokens.surface2),
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
                'TOTAL INDEXED FILES',
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

  List<Widget> _buildSkeletonSlivers(BuildContext context) {
    final tokens = context.tokens;
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: tokens.border.withValues(alpha: 0.15),
                ),
                top: i == 0
                    ? BorderSide(color: tokens.border.withValues(alpha: 0.15))
                    : BorderSide.none,
              ),
              color: tokens.surface1,
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
                      Container(
                        height: 11,
                        width: double.infinity,
                        color: tokens.surface2,
                      ),
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
        description: (_error ?? 'Unknown error').toUpperCase(),
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
      childAspectRatio: 0.72,
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
    final metadata = item.isDirectory
        ? '${item.itemCount} items'
        : [if (item.sizeLabel.isNotEmpty) item.sizeLabel, item.typeLabel]
              .join(' · ');

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
// FILE GRID CARD (Match ModernMobileUIScreen 78/22 Split)
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
            flex: 78,
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
          // Info area (22%)
          Expanded(
            flex: 22,
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: tokens.surface1,
                border: Border(
                  top: BorderSide(
                    color: tokens.border.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w500,
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
        _sortItem(context, 'name', 'NAME'),
        _sortItem(context, 'size', 'SIZE'),
        _sortItem(context, 'type', 'TYPE'),
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
