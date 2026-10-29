// presentation/tv/tv_home_screen.dart
// ============================================================================
// STREAMZ — TV Home Screen
// ============================================================================

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
import 'package:streamz/presentation/client/widgets/client_library_state.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_brand_icon.dart';
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
    final recentlyPlayed = vm.recentlyPlayed;
    final videos = vm.videos;
    final audio = vm.audio;
    final images = vm.images;

    final size = MediaQuery.sizeOf(context);
    final tokens = context.tokens;
    final sidePadding = (size.width * 0.03).clamp(16.0, 48.0);
    final vSpacing = (size.height * 0.03).clamp(16.0, 40.0);

    final featuredItems = [...continueWatching, ...videos].take(5).toList();
    var nextRailIndex = 0;
    final stationsRailIndex = stations.isNotEmpty ? nextRailIndex++ : -1;
    final continueRailIndex =
        continueWatching.isNotEmpty ? nextRailIndex++ : -1;
    final recentRailIndex = recentlyPlayed.isNotEmpty ? nextRailIndex++ : -1;
    final videoRailIndex = videos.isNotEmpty ? nextRailIndex++ : -1;
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
            if (allMedia.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ClientLibraryStateView(
                  isLoading: vm.isLoading,
                  isConnected: vm.isConnected,
                  error: vm.connectionError,
                  onReconnect: () => context.go('/client/connect'),
                ),
              )
            else ...[
              if (featuredItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: size.height * 0.75,
                    width: double.infinity,
                    child: TVHeroSection(
                      items: featuredItems,
                      vm: vm,
                      allItems: allMedia,
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 100)),

              SliverToBoxAdapter(child: SizedBox(height: vSpacing)),

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

              if (continueWatching.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVContentRail(
                    title: AppStrings.continueWatching,
                    items: continueWatching,
                    showProgress: true,
                    railIndex: continueRailIndex,
                    focusedRail: _railFocus,
                    onRailFocus: (i) => setState(() => _railFocus = i),
                    vm: vm,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
              ],

              if (recentlyPlayed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVContentRail(
                    title: AppStrings.recentlyPlayed,
                    items: recentlyPlayed,
                    railIndex: recentRailIndex,
                    focusedRail: _railFocus,
                    onRailFocus: (i) => setState(() => _railFocus = i),
                    vm: vm,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
              ],

              if (videos.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: TVContentRail(
                    title: AppStrings.videoArchive,
                    items: videos,
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
      title: Row(
        children: [
          AppBrandIcon(
            size: (size.width * 0.03).clamp(28.0, 44.0).toDouble(),
          ),
          SizedBox(width: (size.width * 0.01).clamp(10.0, 16.0)),
          Flexible(
            child: Text(
              AppStrings.streamzStudio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.display(
                (size.width * 0.015).clamp(18.0, 28.0),
                spacing: 4,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
      centerTitle: false,
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
            onKeyEvent: (_, event) => handleTVSelectKey(
              event,
              () => context.push('/settings'),
            ),
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

  List<MediaItem> get _results {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return widget.allMedia
        .where((m) => m.title.toLowerCase().contains(q))
        .take(50)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
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
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        _query.trim().isEmpty
                            ? 'TYPE TO SEARCH YOUR MEDIA'
                            : 'NO MATCHING MEDIA',
                        style: AppTextStyles.text(
                          16,
                          spacing: 4,
                          color: tokens.textMuted,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(48),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                        childAspectRatio: 1.0,
                      ),
                      itemCount: results.length,
                      itemBuilder: (ctx, i) => _TVSearchCard(
                        item: results[i],
                        allItems: results,
                        onFocus: () {},
                      ),
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
    required this.item,
    required this.allItems,
    required this.onFocus,
  });
  final MediaItem item;
  final List<MediaItem> allItems;
  final VoidCallback onFocus;

  @override
  State<_TVSearchCard> createState() => _TVSearchCardState();
}

class _TVSearchCardState extends State<_TVSearchCard> {
  bool _focused = false;

  void _play() {
    context.push(
      '/tv-player',
      extra: {
        'items': widget.allItems,
        'startIndex': widget.allItems.indexOf(widget.item),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Focus(
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
                  child: NetworkImageFade(
                    url: context.read<ClientViewModel>().thumbnailUrl(
                      widget.item.id,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    widget.item.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.text(
                      10,
                      color: _focused
                          ? tokens.textPrimary
                          : tokens.textSecondary,
                    ),
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
