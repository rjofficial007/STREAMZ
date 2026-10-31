// presentation/tv/tv_file_manager.dart
// ============================================================================
// STREAMZ — TV File Manager
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_bottom_sheet.dart';
import 'package:streamz/presentation/shared/app_live_station_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
import 'package:streamz/presentation/shared/file_item.dart';
import 'package:streamz/presentation/tv/tv_player_screen.dart';

class TVFileManagerScreen extends StatefulWidget {
  const TVFileManagerScreen({super.key});

  @override
  State<TVFileManagerScreen> createState() => _TVFileManagerScreenState();
}

class _TVFileManagerScreenState extends State<TVFileManagerScreen> {
  final List<String?> _navStack = [null];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  List<SFileItem> _items = [];
  List<SFileItem> _allItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _browseHasMore = false;
  int _browseOffset = 0;
  int _browseGeneration = 0;
  String? _loadedBrowsePath;
  String? _error;

  String _searchQuery = '';
  Timer? _searchDebounce;
  String _activeCategory = 'video';

  List<SFileItem> _activePlaylist = [];
  int _activePlayIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onBrowseScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHome();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
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
      _switchCategory('video', SFileType.video);
    } catch (_) {
      _switchCategory('video', SFileType.video);
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
      _searchQuery = query.toLowerCase();
      if (query.isEmpty) _searchController.clear();
    });
    try {
      final page = await context.read<ClientViewModel>().browseRemotePage(
        path,
        offset: 0,
        query: query,
      );
      final items = page.items.map(SFileItem.fromJson).toList()
        ..sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
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
        _scrollController.position.extentAfter < 500) {
      _loadMoreBrowseItems();
    }
  }

  Future<void> _loadMoreBrowseItems() async {
    final path = _loadedBrowsePath;
    if (!mounted ||
        _isLoading ||
        _isLoadingMore ||
        !_browseHasMore ||
        path == null) {
      return;
    }
    final generation = _browseGeneration;
    setState(() => _isLoadingMore = true);
    try {
      final page = await context.read<ClientViewModel>().browseRemotePage(
        path,
        offset: _browseOffset,
        query: _searchQuery,
      );
      if (!mounted || generation != _browseGeneration) return;
      setState(() {
        _items = [..._items, ...page.items.map(SFileItem.fromJson)]
          ..sort((a, b) {
            if (a.isDirectory && !b.isDirectory) return -1;
            if (!a.isDirectory && b.isDirectory) return 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
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

  void _switchCategory(String cat, SFileType? filter) {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _activeCategory = cat;
      _searchQuery = '';
    });
    if (cat == 'folder') {
      _loadedBrowsePath = '';
      _navStack
        ..clear()
        ..add('');
      _loadPath('');
    } else if (cat == 'station') {
      _loadedBrowsePath = null;
      _browseHasMore = false;
      context.read<ClientViewModel>().refresh();
      setState(() {
        _isLoading = false;
      });
    } else {
      _loadedBrowsePath = null;
      _browseHasMore = false;
      setState(() {
        _items = filter != null
            ? _allItems.where((i) => i.type == filter).toList()
            : [];
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
      _showOptionsSheet(item);
    }
  }

  Future<void> _tuneIn(BroadcastStation station) async {
    final vm = context.read<ClientViewModel>();
    final res = await vm.joinStation(station.id);
    if (res != null && mounted) {
      unawaited(
        context.push(
          '/tv-player',
          extra: {
            'items': res.playlist,
            'startIndex': res.itemIndex,
            'isPathBased': false,
            'startOffset': res.position,
            'autoPlay': !res.isPaused,
          },
        ),
      );
    }
  }

  void _triggerDownload(SFileItem item) {
    final mediaItem = MediaItem(
      id: item.path,
      title: item.name,
      duration: 0,
      type: item.mediaType,
      folder: 'Download',
    );
    context.read<ClientViewModel>().downloadMedia(
      item: mediaItem,
      isPathBased: item.isPathBased,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Downloading ${item.name}',
          style: AppTextStyles.bodyLarge.copyWith(
            color: context.tokens.textPrimary,
          ),
        ),
        backgroundColor: context.tokens.surface3,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.radius(12)),
        ),
      ),
    );
  }

  void _showOptionsSheet(SFileItem item) {
    showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(
                title: item.name,
                subtitle: item.isDirectory ? 'Folder options' : 'Media options',
                icon: item.isDirectory ? LucideIcons.folder : LucideIcons.file,
              ),
              if (item.isPlayable)
                _TVModalBtn(
                  label: 'Play media',
                  autoFocus: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openItem(item);
                  },
                ),
              if (!item.isDirectory)
                _TVModalBtn(
                  label: 'Download to device',
                  autoFocus: !item.isPlayable,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _triggerDownload(item);
                  },
                ),
              _TVModalBtn(
                label: 'Cancel',
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<SFileItem> get _displayItems {
    final query = _searchQuery.trim();
    if (query.isEmpty) return _items;
    return _items.where((i) => i.name.toLowerCase().contains(query)).toList();
  }

  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      if (_activeCategory == 'folder' && _loadedBrowsePath != null) {
        _loadPath(_loadedBrowsePath!);
      } else {
        setState(() => _searchQuery = '');
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final normalized = query.trim().toLowerCase();
      if (_activeCategory == 'folder' && _loadedBrowsePath != null) {
        _loadPath(_loadedBrowsePath!, query: normalized);
      } else {
        setState(() => _searchQuery = normalized);
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_activeCategory == 'folder' && _loadedBrowsePath != null) {
      _loadPath(_loadedBrowsePath!);
    } else {
      setState(() => _searchQuery = '');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final size = MediaQuery.sizeOf(context);
    final tokens = context.tokens;
    final sidePadding = DS.hPad(size.width);

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
      child: AppScaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
                // Persistent TV Top Bar
                AppSliverAppBar(
                  floating: true,
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
                          if (f) {
                            Scrollable.ensureVisible(
                              context,
                              alignment: 0.0,
                              duration: const Duration(milliseconds: 250),
                            );
                          }
                        },
                        onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
                          if (!_goBack()) Navigator.pop(context);
                        }),
                        child: AppBackButton(
                          color: tokens.textPrimary,
                          iconSize: (size.width * 0.015).clamp(20.0, 28.0),
                          onPressed: () {
                            if (!_goBack()) Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    'Browse media',
                    style: AppTextStyles.style(
                      fontSize: (size.width * 0.015).clamp(18.0, 26.0),
                      color: tokens.textPrimary,
                      fontWeight: AppTextStyles.titleFontWeight,
                    ),
                  ),
                  actions: [
                    Center(
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.wifi,
                            size: 16,
                            color: tokens.textSecondary,
                          ),
                          const SizedBox(width: DS.s8),
                          Text(
                            vm.targetIp,
                            style: AppTextStyles.style(
                              color: tokens.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: DS.s24),
                        ],
                      ),
                    ),
                  ],
                ),

                // Category Rail
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    child: SizedBox(
                      height: (size.height * 0.08).clamp(50.0, 70.0),
                      child: Row(
                        children: [
                          _TopNavBtn(
                            label: 'Videos',
                            isActive: _activeCategory == 'video',
                            onTap: () =>
                                _switchCategory('video', SFileType.video),
                          ),
                          _TopNavBtn(
                            label: 'Audio',
                            isActive: _activeCategory == 'audio',
                            onTap: () =>
                                _switchCategory('audio', SFileType.audio),
                          ),
                          _TopNavBtn(
                            label: 'Photos',
                            isActive: _activeCategory == 'image',
                            onTap: () =>
                                _switchCategory('image', SFileType.image),
                          ),
                          _TopNavBtn(
                            label: 'Folders',
                            isActive: _activeCategory == 'folder',
                            onTap: () => _switchCategory('folder', null),
                          ),
                          _TopNavBtn(
                            label: 'Stations',
                            isActive: _activeCategory == 'station',
                            onTap: () => _switchCategory('station', null),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      sidePadding,
                      DS.s12,
                      sidePadding,
                      DS.s8,
                    ),
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          // Move focus down to the first item in the grid
                          node.focusInDirection(TraversalDirection.down);
                          return KeyEventResult.handled;
                        }
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          // Move focus up to the category rail
                          node.focusInDirection(TraversalDirection.up);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: tokens.surface2,
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.search,
                              color: tokens.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: _scheduleSearch,
                                style: AppTextStyles.body.copyWith(
                                  color: tokens.textPrimary,
                                  letterSpacing: 0.2,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search media',
                                  hintStyle: AppTextStyles.body.copyWith(
                                    color: tokens.textMuted,
                                  ),
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
                AppContentSliver(
                  maxWidth: 1800,
                  sliver: _buildSliverContent(context, size, sidePadding, vm),
                ),

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
    );
  }

  Widget _buildSliverContent(
    BuildContext context,
    Size size,
    double sidePadding,
    ClientViewModel vm,
  ) {
    if (_isLoading) {
      return const AppStateSliver(
        state: AppStateView(
          kind: AppStateKind.loading,
          title: 'Loading media library',
        ),
      );
    }

    if (_error != null) {
      return AppStateSliver(
        state: AppStateView(
          kind: AppStateKind.error,
          title: 'Couldn’t load media',
          description: _error,
          icon: LucideIcons.alertTriangle,
          actionLabel: 'Retry connection',
          onAction: _loadHome,
        ),
      );
    }

    if (_activeCategory == 'station') {
      final stations = vm.stations;
      if (stations.isEmpty) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: AppStateView(
            title: 'No live broadcasts yet',
            description: 'Active streams from this server will appear here.',
            icon: LucideIcons.radioTower,
          ),
        );
      }
      final stationColumns = DS.responsiveColumns(
        context,
        availableWidth: size.width - (sidePadding * 2),
        spacing: DS.s16,
        minTileWidth: 280,
        maxColumns: 4,
      );
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: sidePadding),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: stationColumns,
            childAspectRatio: 1.65,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) => AppLiveStationCard(
              title: stations[i].name,
              trackTitle:
                  stations[i].nowPlaying?.item.title ?? 'Waiting for a stream',
              onTap: () => _tuneIn(stations[i]),
            ),
            childCount: stations.length,
          ),
        ),
      );
    }

    final filtered = _displayItems;
    if (filtered.isEmpty) {
      final isSearching = _searchQuery.isNotEmpty;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppStateView(
          title: isSearching ? 'No matching media' : 'Nothing here yet',
          description: isSearching
              ? 'Try a different search or clear the current query.'
              : 'Media in this category will appear here.',
          icon: isSearching ? LucideIcons.searchX : LucideIcons.folderOpen,
          actionLabel: isSearching ? 'Clear search' : null,
          onAction: isSearching ? _clearSearch : null,
        ),
      );
    }

    final crossAxisCount = DS.responsiveColumns(
      context,
      availableWidth: size.width - (sidePadding * 2),
      spacing: DS.s16,
      minTileWidth: 220,
      maxColumns: 10,
    );

    final grid = SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: sidePadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => _TVGridCard(
            item: filtered[i],
            vm: context.read<ClientViewModel>(),
            onTap: () => _openItem(filtered[i]),
            onLongPress: () => _showOptionsSheet(filtered[i]),
          ),
          childCount: filtered.length,
        ),
      ),
    );
    if (!_browseHasMore && !_isLoadingMore) return grid;
    return SliverMainAxisGroup(
      slivers: [
        grid,
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(DS.s24),
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE TV PLAYER (Logic Guard)
// ─────────────────────────────────────────────────────────────────────────────

class _TVInlinePlayer extends StatefulWidget {
  const _TVInlinePlayer({
    required this.playlist,
    required this.startIndex,
    required this.vm,
    required this.onClose,
  });
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
    final mediaItems = widget.playlist
        .map(
          (f) => MediaItem(
            id: f.path,
            title: f.name,
            duration: 0,
            type: f.mediaType,
            folder: 'SYS',
          ),
        )
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TVPlayerScreen(
          items: mediaItems,
          startIndex: widget.startIndex,
          isPathBased: widget.playlist[widget.startIndex].isPathBased,
        ),
      ),
    ).then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// TV GRID CARD (Poster and metadata layout)
// ─────────────────────────────────────────────────────────────────────────────

class _TVGridCard extends StatefulWidget {
  const _TVGridCard({
    required this.item,
    required this.vm,
    required this.onTap,
    required this.onLongPress,
  });
  final SFileItem item;
  final ClientViewModel vm;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_TVGridCard> createState() => _TVGridCardState();
}

class _TVGridCardState extends State<_TVGridCard>
    with SingleTickerProviderStateMixin {
  bool _focused = false;
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
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
          ? (widget.item.type == SFileType.image
                ? widget.vm.fileUrl(widget.item.path)
                : widget.vm.thumbnailUrlForPath(widget.item.path))
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
                color: _focused ? tokens.surface3 : tokens.surface1,
                borderRadius: BorderRadius.circular(DS.radius(18)),
                border: Border.all(
                  color: _focused ? tokens.focusColor : tokens.border,
                  width: _focused ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DS.radius(17)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                                fallbackIcon: widget.item.icon,
                              ),
                            )
                          else
                            Container(
                              color: isDir ? tokens.surface2 : tokens.surface1,
                              child: Center(
                                child: Icon(
                                  widget.item.icon,
                                  color: tokens.textSecondary,
                                  size: 40,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 25,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              widget.item.cardMetadata,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
// TOP NAV BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _TopNavBtn extends StatefulWidget {
  const _TopNavBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

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
                color: widget.isActive || _focused
                    ? tokens.surface3
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(DS.radius(12)),
                border: Border.all(
                  color: widget.isActive || _focused
                      ? tokens.focusColor
                      : Colors.transparent,
                ),
              ),
              child: Text(
                widget.label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: widget.isActive
                      ? FontWeight.w500
                      : FontWeight.normal,
                  letterSpacing: 0.5,
                  color: tokens.textPrimary,
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
class _TVModalBtn extends StatefulWidget {
  const _TVModalBtn({
    required this.label,
    required this.onTap,
    this.autoFocus = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool autoFocus;

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
              color: _focused ? tokens.surface3 : Colors.transparent,
              borderRadius: BorderRadius.circular(DS.radius(14)),
              border: Border.all(
                color: _focused ? tokens.focusColor : Colors.transparent,
              ),
            ),
            child: Text(
              widget.label,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
