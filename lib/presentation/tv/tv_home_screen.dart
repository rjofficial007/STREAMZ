// presentation/tv/tv_home_screen.dart
// ============================================================================
// STREAMZ — TV Home Screen
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/core/theme/theme_tokens.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/client/media_title_search.dart';
import 'package:streamz/presentation/client/widgets/client_connection_notice.dart';
import 'package:streamz/presentation/client/widgets/client_library_state.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
import 'package:streamz/presentation/shared/media_details_text.dart';
import 'package:streamz/presentation/shared/media_favorite_button.dart';
import 'package:streamz/presentation/tv/widgets/tv_content_rail.dart';
import 'package:streamz/presentation/tv/widgets/tv_hero_section.dart';
import 'package:streamz/presentation/tv/widgets/tv_station_rail.dart';

class TVHomeScreen extends StatefulWidget {
  const TVHomeScreen({super.key});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  int _railFocus = -1;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _scrollController.addListener(_onScroll);
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final allMedia = vm.remoteMedia;
    final stations = vm.stations;
    final continueWatching = vm.continueWatching;
    final favorites = vm.favoriteItems;
    final recentlyPlayed = vm.recentlyPlayed;
    final videos = vm.videos;
    final audio = vm.audio;
    final images = vm.images;

    final size = MediaQuery.sizeOf(context);
    final tokens = context.tokens;
    final sidePadding = DS.hPad(size.width);
    final vSpacing = (size.height * 0.03).clamp(16.0, 40.0);

    final continueIds = continueWatching.map((item) => item.id).toSet();
    final featuredItems = videos
        .where((item) => !continueIds.contains(item.id))
        .take(1)
        .toList();
    final featuredIds = featuredItems.map((item) => item.id).toSet();
    final continueRailItems = continueWatching;
    final recentRailItems = recentlyPlayed
        .where(
          (item) =>
              !continueIds.contains(item.id) && !featuredIds.contains(item.id),
        )
        .toList();
    final videoRailItems = videos
        .where((item) => !featuredIds.contains(item.id))
        .toList();
    var nextRailIndex = 0;
    final favoritesRailIndex = favorites.isNotEmpty ? nextRailIndex++ : -1;
    final continueRailIndex = continueRailItems.isNotEmpty
        ? nextRailIndex++
        : -1;
    final stationsRailIndex = stations.isNotEmpty ? nextRailIndex++ : -1;
    final recentRailIndex = recentRailItems.isNotEmpty ? nextRailIndex++ : -1;
    final videoRailIndex = videoRailItems.isNotEmpty ? nextRailIndex++ : -1;
    final audioRailIndex = audio.isNotEmpty ? nextRailIndex++ : -1;
    final imageRailIndex = images.isNotEmpty ? nextRailIndex++ : -1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop();
      },
      child: AppScaffold(
        extendBodyBehindAppBar: true,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            _buildAppBar(context, vm, tokens, sidePadding),
            if (allMedia.isNotEmpty)
              SliverToBoxAdapter(
                child: ClientConnectionNotice(
                  phase: vm.connectionPhase,
                  error: vm.connectionError,
                  onReconnect: () => context.go('/client/connect'),
                  onRetry: () => unawaited(vm.refresh()),
                ),
              ),
            if (allMedia.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ClientLibraryStateView(
                  isLoading: vm.isLoading,
                  connectionPhase: vm.connectionPhase,
                  error: vm.connectionError,
                  onReconnect: () => context.go('/client/connect'),
                  onRefresh: vm.refresh,
                ),
              )
            else ...[
              if (featuredItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: (size.height * 0.56).clamp(340.0, 640.0).toDouble(),
                    width: double.infinity,
                    child: TVHeroSection(
                      items: featuredItems,
                      vm: vm,
                      allItems: allMedia,
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: vSpacing)),

              if (favorites.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVContentRail(
                    title: AppStrings.favorites,
                    items: favorites,
                    railIndex: favoritesRailIndex,
                    focusedRail: _railFocus,
                    onRailFocus: (i) => setState(() => _railFocus = i),
                    vm: vm,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
              ],

              if (continueRailItems.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVContentRail(
                    title: AppStrings.continueWatching,
                    items: continueRailItems,
                    showProgress: true,
                    railIndex: continueRailIndex,
                    focusedRail: _railFocus,
                    onRailFocus: (i) => setState(() => _railFocus = i),
                    vm: vm,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
              ],

              if (stations.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVStationRail(
                    stations: stations,
                    railIndex: stationsRailIndex,
                    onRailFocus: (i) => setState(() => _railFocus = i),
                    vm: vm,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
              ],

              if (recentRailItems.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVContentRail(
                    title: AppStrings.recentlyPlayed,
                    items: recentRailItems,
                    railIndex: recentRailIndex,
                    focusedRail: _railFocus,
                    onRailFocus: (i) => setState(() => _railFocus = i),
                    vm: vm,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
              ],

              if (videoRailItems.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVContentRail(
                    title: AppStrings.videoArchive,
                    items: videoRailItems,
                    railIndex: videoRailIndex,
                    focusedRail: _railFocus,
                    onRailFocus: (i) => setState(() => _railFocus = i),
                    vm: vm,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
              ],

              if (audio.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVContentRail(
                    title: AppStrings.audioMatrix,
                    items: audio,
                    railIndex: audioRailIndex,
                    focusedRail: _railFocus,
                    onRailFocus: (i) => setState(() => _railFocus = i),
                    vm: vm,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
              ],

              if (images.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVContentRail(
                    title: AppStrings.photoDb,
                    items: images,
                    railIndex: imageRailIndex,
                    focusedRail: _railFocus,
                    onRailFocus: (i) => setState(() => _railFocus = i),
                    vm: vm,
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ClientViewModel vm,
    StreamzThemeExtension tokens,
    double sidePadding,
  ) {
    final size = MediaQuery.sizeOf(context);
    return AppSliverAppBar(
      floating: true,
      pinned: true,
      toolbarHeight: (size.height * 0.08).clamp(50.0, 80.0),
      leadingWidth: sidePadding + 48,
      leading: Padding(
        padding: EdgeInsets.only(left: sidePadding),
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                context.pop();
                return null;
              },
            ),
          },
          child: Focus(
            onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => context.pop()),
            child: AppBackButton(
              iconSize: (size.width * 0.015).clamp(20.0, 28.0),
              color: tokens.textPrimary,
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      title: Text(
        AppStrings.appTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.display(
          (size.width * 0.015).clamp(18.0, 28.0),
          spacing: 4,
          color: tokens.textPrimary,
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: sidePadding),
          child: Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _openSearch(context, vm.remoteMedia);
                  return null;
                },
              ),
            },
            child: Focus(
              onKeyEvent: (_, ev) => handleTVSelectKey(
                ev,
                () => _openSearch(context, vm.remoteMedia),
              ),
              child: IconButton(
                tooltip: AppStrings.search,
                icon: Icon(
                  AppIcons.search,
                  color: tokens.textPrimary,
                  size: (size.width * 0.015).clamp(20.0, 28.0),
                ),
                onPressed: () => _openSearch(context, vm.remoteMedia),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: sidePadding),
          child: Focus(
            onKeyEvent: (_, event) =>
                handleTVSelectKey(event, () => context.push('/settings')),
            child: IconButton(
              tooltip: 'Appearance settings',
              icon: Icon(
                AppIcons.settings,
                color: tokens.textPrimary,
                size: (size.width * 0.015).clamp(20.0, 28.0),
              ),
              onPressed: () => context.push('/settings'),
            ),
          ),
        ),
      ],
    );
  }

  void _openSearch(BuildContext context, List<MediaItem> allMedia) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ChangeNotifierProvider.value(
          value: context.read<ClientViewModel>(),
          child: _TVSearchScreen(allMedia: allMedia),
        ),
        transitionsBuilder: (_, a, _, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }
}

class _TVSearchScreen extends StatefulWidget {
  const _TVSearchScreen({required this.allMedia});
  final List<MediaItem> allMedia;

  @override
  State<_TVSearchScreen> createState() => _TVSearchScreenState();
}

class _TVSearchScreenState extends State<_TVSearchScreen> {
  String _query = '';
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late final MediaTitleSearch _search = MediaTitleSearch(widget.allMedia);
  Timer? _searchDebounce;
  List<MediaItem> _results = const [];
  bool _hasMoreResults = false;
  bool _isSearching = false;

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _query = value;
      _isSearching = value.trim().isNotEmpty;
      _results = const [];
      _hasMoreResults = false;
    });
    if (value.trim().isEmpty) return;

    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final result = _search.search(value);
      setState(() {
        _results = result.items;
        _hasMoreResults = result.hasMore;
        _isSearching = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final results = _results;

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              child: Row(
                children: [
                  AppBackButton(onPressed: () => context.pop()),
                  const SizedBox(width: 12),
                  const Icon(AppIcons.search, color: DS.textPrimary, size: 32),
                  const SizedBox(width: 24),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: AppTextStyles.text(
                        24,
                        spacing: 2,
                        color: tokens.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: AppStrings.searchSignalHint,
                        hintStyle: TextStyle(color: DS.textMuted),
                        border: InputBorder.none,
                      ),
                      onChanged: _onQueryChanged,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? const AppStateView(
                      title: 'Search your media',
                      description:
                          'Type a title to find items in this library.',
                      icon: AppIcons.search,
                    )
                  : _isSearching
                  ? const AppStateView(
                      title: 'Searching media',
                      kind: AppStateKind.loading,
                    )
                  : results.isEmpty
                  ? const AppStateView(
                      title: 'No matching media',
                      description: 'Try another title.',
                      icon: AppIcons.search,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(48, 0, 48, 0),
                          child: Text(
                            _hasMoreResults
                                ? 'Showing 50 of 50+ matches'
                                : '${results.length} results',
                            style: AppTextStyles.caption.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(48),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      (MediaQuery.sizeOf(context).width /
                                              (320 *
                                                  MediaQuery.textScalerOf(
                                                    context,
                                                  ).scale(20) /
                                                  20))
                                          .floor()
                                          .clamp(2, 8),
                                  crossAxisSpacing: 24,
                                  mainAxisSpacing: 24,
                                  childAspectRatio: 0.88,
                                ),
                            itemCount: results.length,
                            itemBuilder: (ctx, i) => _TVSearchCard(
                              key: ValueKey(results[i].id),
                              item: results[i],
                              allItems: results,
                              vm: context.read<ClientViewModel>(),
                              onFocus: () {},
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TVSearchCard extends StatefulWidget {
  const _TVSearchCard({
    super.key,
    required this.item,
    required this.allItems,
    required this.vm,
    required this.onFocus,
  });
  final MediaItem item;
  final List<MediaItem> allItems;
  final ClientViewModel vm;
  final VoidCallback onFocus;

  @override
  State<_TVSearchCard> createState() => _TVSearchCardState();
}

class _TVSearchCardState extends State<_TVSearchCard> {
  bool _focused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TV search ${widget.item.id}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    await context.push<void>(
      '/tv-player',
      extra: {
        'items': widget.allItems,
        'startIndex': widget.allItems.indexOf(widget.item),
      },
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      handleTVFocusScroll(true, context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) widget.onFocus();
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, _play),
      child: GestureDetector(
        onTap: _play,
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surface2,
              border: Border.all(
                color: _focused
                    ? tokens.textPrimary
                    : tokens.border.withValues(alpha: 0.15),
                width: _focused ? 4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetworkImageFade(
                            url: widget.vm.thumbnailUrl(widget.item.id),
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: MediaFavoriteButton(
                              item: widget.item,
                              viewModel: widget.vm,
                              tvFocus: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.text(
                          10,
                          color: _focused
                              ? tokens.textPrimary
                              : tokens.textSecondary,
                        ),
                      ),
                      MediaDetailsText(item: widget.item),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
