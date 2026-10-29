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
import 'package:streamz/presentation/shared/app_live_station_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHome();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      _showOptionsModal(item);
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
          'CMD // DOWNLOADING ${item.name.toUpperCase()}',
          style: AppTextStyles.bodyLarge.copyWith(
            color: kWebBlack,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: kWebWhite,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radius(12))),
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
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: kWebBorder)),
                  ),
                  child: Text(
                    item.name.toUpperCase(),
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: kWebWhite,
                      fontWeight: AppTextStyles.titleFontWeight,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                _TVModalBtn(
                  label: 'CANCEL OPERATION',
                  isDestructive: true,
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<SFileItem> get _displayItems {
    if (_searchQuery.isEmpty) return _items;
    return _items
        .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final size = MediaQuery.sizeOf(context);
    final sidePadding = (size.width * 0.04).clamp(32.0, 80.0);

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
                          color: kWebWhite,
                          iconSize: (size.width * 0.015).clamp(20.0, 28.0),
                          onPressed: () {
                            if (!_goBack()) Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    'STREAMZ',
                    style: AppTextStyles.style(
                      fontSize: (size.width * 0.015).clamp(18.0, 28.0),
                      letterSpacing: 0.8,
                      color: kWebWhite,
                      fontWeight: FontWeight.w300,
                    ),
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
                            style: AppTextStyles.style(
                              color: kWebText,
                              fontSize: (size.width * 0.008).clamp(9.0, 12.0),
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
                  child: Container(
                    height: (size.height * 0.08).clamp(50.0, 70.0),
                    margin: EdgeInsets.zero,
                    decoration: const BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: kWebBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        _TopNavBtn(
                          label: 'VIDEOS',
                          isActive: _activeCategory == 'video',
                          onTap: () =>
                              _switchCategory('video', SFileType.video),
                        ),
                        _TopNavBtn(
                          label: 'AUDIO',
                          isActive: _activeCategory == 'audio',
                          onTap: () =>
                              _switchCategory('audio', SFileType.audio),
                        ),
                        _TopNavBtn(
                          label: 'PHOTOS',
                          isActive: _activeCategory == 'image',
                          onTap: () =>
                              _switchCategory('image', SFileType.image),
                        ),
                        _TopNavBtn(
                          label: 'NETWORK',
                          isActive: _activeCategory == 'folder',
                          onTap: () => _switchCategory('folder', null),
                        ),
                        _TopNavBtn(
                          label: 'STATIONS',
                          isActive: _activeCategory == 'station',
                          onTap: () => _switchCategory('station', null),
                        ),
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
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: kWebSurface,
                          border: Border.all(color: kWebBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.search,
                              color: kWebTextMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                focusNode: _searchFocusNode,
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                style: AppTextStyles.body.copyWith(
                                  color: kWebWhite,
                                  letterSpacing: 0.2,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'SEARCH SIGNALS...',
                                  hintStyle: AppTextStyles.body.copyWith(
                                    color: kWebTextMuted,
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
          title: 'Signal error',
          description: _error?.toUpperCase(),
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
            title: 'No live broadcasts',
            description: 'Active broadcasts from your network will appear here.',
            icon: LucideIcons.radioTower,
          ),
        );
      }
      final stationColumns = (size.width / 480).floor().clamp(3, 8).toInt();
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
      return SliverFillRemaining(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
            decoration: BoxDecoration(
              border: Border.all(color: kWebBorder, style: BorderStyle.solid),
            ),
            child: Text(
              '0 SIGNALS FOUND',
              style: AppTextStyles.bodyLarge.copyWith(
                color: kWebTextMuted,
                letterSpacing: 0.8,
              ),
            ),
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
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => _TVGridCard(
            item: filtered[i],
            vm: context.read<ClientViewModel>(),
            onTap: () => _openItem(filtered[i]),
            onLongPress: () => _showOptionsModal(filtered[i]),
          ),
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
                color: _focused ? kWebSurface : kWebSurface2,
                borderRadius: BorderRadius.circular(DS.radius(18)),
                border: Border.all(
                  color: _focused ? kWebWhite : kWebBorder,
                  width: _focused ? 3 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DS.radius(17)),
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
                              child: NetworkImageFade(
                                url: thumbUrl,
                                fit: BoxFit.cover,
                                fallbackIcon: widget.item.icon,
                              ),
                            )
                          else
                            Container(
                              color: isDir ? kWebSurface : kWebSurface2,
                              child: Center(
                                child: Icon(
                                  widget.item.icon,
                                  color: kWebWhite,
                                  size: 40,
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
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: kWebBorder)),
                        ),
                        child: Text(
                          widget.item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: kWebText,
                            fontWeight: FontWeight.w500,
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
              color: widget.isActive
                  ? kWebWhite
                  : (_focused
                        ? kWebWhite.withValues(alpha: 0.1)
                        : Colors.transparent),
              border: const Border(right: BorderSide(color: kWebBorder)),
            ),
            child: Text(
              widget.label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: widget.isActive
                    ? FontWeight.w500
                    : FontWeight.normal,
                letterSpacing: 0.5,
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
class _TVModalBtn extends StatefulWidget {
  const _TVModalBtn({
    required this.label,
    required this.onTap,
    this.autoFocus = false,
    this.isDestructive = false,
  });
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
            color: _focused
                ? (widget.isDestructive ? DS.danger : kWebWhite)
                : Colors.transparent,
            border: const Border(bottom: BorderSide(color: kWebBorder)),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: _focused
                  ? kWebBlack
                  : (widget.isDestructive ? DS.danger : kWebWhite),
            ),
          ),
        ),
      ),
    ),
  );
}
