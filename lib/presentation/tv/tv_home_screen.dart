// presentation/tv/tv_home_screen.dart
// ============================================================================
// STREAMZ — TV Home Screen (Brutalist Web Studio Edition)
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
import 'package:streamz/presentation/shared/atmospheric_background.dart';
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
      DeviceOrientation.landscapeRight
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
      DeviceOrientation.portraitUp
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final allMedia = vm.remoteMedia;
    final stations = vm.stations;
    final continueWatching = vm.continueWatching;
    final videos = vm.videos;
    final audio = vm.audio;
    final images = vm.images;

    final size = MediaQuery.sizeOf(context);
    final tokens = context.tokens;
    final sidePadding = (size.width * 0.03).clamp(16.0, 48.0);
    final vSpacing = (size.height * 0.03).clamp(16.0, 40.0);

    final featuredItems = [...continueWatching, ...videos].take(5).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop();
      },
      child: Scaffold(
        backgroundColor: tokens.background,
        extendBodyBehindAppBar: true,
        body: AtmosphericBackground(
          child: allMedia.isEmpty
              ? const Center(child: _EmptyState())
              : CustomScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  _buildAppBar(context, vm, tokens, sidePadding),

                  if (featuredItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: size.height * 0.75,
                        width: double.infinity,
                        child: TVHeroSection(items: featuredItems, vm: vm, allItems: allMedia),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),

                  SliverToBoxAdapter(child: SizedBox(height: vSpacing)),

                  if (stations.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: TVStationRail(
                        stations: stations, 
                        railIndex: 0, 
                        focusedRail: _railFocus, 
                        onRailFocus: (i) => setState(() => _railFocus = i), 
                        vm: vm
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
                  ],

                  if (continueWatching.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: TVContentRail(
                        title: AppStrings.continueWatching,
                        subTitle: AppStrings.pathResume,
                        items: continueWatching,
                        showProgress: true,
                        railIndex: stations.isNotEmpty ? 1 : 0,
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
                        subTitle: AppStrings.pathVideos,
                        items: videos,
                        railIndex: (stations.isNotEmpty ? 1 : 0) + (continueWatching.isNotEmpty ? 1 : 0),
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
                        subTitle: AppStrings.pathAudio,
                        items: audio,
                        railIndex: _calcRailIndex(stations, continueWatching, videos, 2),
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
                        subTitle: AppStrings.pathImages,
                        items: images,
                        railIndex: _calcRailIndex(stations, continueWatching, videos, 3),
                        focusedRail: _railFocus,
                        onRailFocus: (i) => setState(() => _railFocus = i),
                        vm: vm,
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    ),
    );
  }

  Widget _buildAppBar(BuildContext context, ClientViewModel vm, StreamzThemeExtension tokens, double sidePadding) {
    final size = MediaQuery.sizeOf(context);
    return SliverAppBar(
      backgroundColor: _isScrolled ? tokens.surface1 : Colors.transparent,
      floating: true,
      elevation: 0,
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
            child: IconButton(
              tooltip: AppStrings.back,
              icon: Icon(AppIcons.back, color: tokens.textPrimary, size: (size.width * 0.015).clamp(20.0, 28.0)),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      title: Text(
        AppStrings.streamzStudio,
        style: AppTextStyles.barlowBlack((size.width * 0.015).clamp(18.0, 28.0), spacing: 4, color: tokens.textPrimary),
      ),
      centerTitle: false,
      actions: [
        Center(
          child: Row(
            children: [
              Container(width: 6, height: 6, color: tokens.accent),
              const SizedBox(width: DS.s8),
              Text(
                'TGT // ${vm.targetIp}',
                style: AppTextStyles.mono((size.width * 0.008).clamp(9.0, 12.0), color: tokens.textSecondary),
              ),
              const SizedBox(width: DS.s24),
            ],
          ),
        ),
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
              onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => _openSearch(context, vm.remoteMedia)),
              child: IconButton(
                tooltip: AppStrings.search,
                icon: Icon(AppIcons.search, color: tokens.textPrimary, size: (size.width * 0.015).clamp(20.0, 28.0)),
                onPressed: () => _openSearch(context, vm.remoteMedia),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: AnimatedOpacity(
          opacity: _isScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
        ),
      ),
    );
  }

  int _calcRailIndex(List stations, List continueWatching, List videos, int baseOffset) {
    var idx = stations.isNotEmpty ? 1 : 0;
    if (continueWatching.isNotEmpty) idx++;
    if (videos.isNotEmpty) idx++;
    return idx + baseOffset - 2;
  }

  void _openSearch(BuildContext context, List<MediaItem> allMedia) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ChangeNotifierProvider.value(
          value: context.read<ClientViewModel>(),
          child: _TVSearchScreen(allMedia: allMedia),
        ),
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
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
    return widget.allMedia.where((m) => m.title.toLowerCase().contains(q)).take(50).toList();
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

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
              child: Row(
                children: [
                  const Icon(AppIcons.search, color: DS.textPrimary, size: 32),
                  const SizedBox(width: 24),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: AppTextStyles.mono(24, spacing: 2, color: tokens.textPrimary),
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
                  ? Center(child: Text(AppStrings.noSignals.toUpperCase(), style: AppTextStyles.mono(16, spacing: 4, color: tokens.textMuted)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(48),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5, 
                        crossAxisSpacing: 24, 
                        mainAxisSpacing: 24, 
                        childAspectRatio: 1.0
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
  const _TVSearchCard({required this.item, required this.allItems, required this.onFocus});
  final MediaItem item;
  final List<MediaItem> allItems;
  final VoidCallback onFocus;

  @override
  State<_TVSearchCard> createState() => _TVSearchCardState();
}

class _TVSearchCardState extends State<_TVSearchCard> {
  bool _focused = false;

  void _play() {
    context.push('/tv-player', extra: {
      'items': widget.allItems,
      'startIndex': widget.allItems.indexOf(widget.item),
    });
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
              border: Border.all(color: _focused ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15), width: _focused ? 4 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: NetworkImageFade(
                    url: context.read<ClientViewModel>().thumbnailUrl(widget.item.id),
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    widget.item.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.mono(10, color: _focused ? tokens.textPrimary : tokens.textSecondary),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.wifiOff, size: 64, color: DS.textMuted),
        const SizedBox(height: 24),
        Text(
          '${AppStrings.signalLost} // NO_CONTENT',
          style: AppTextStyles.barlowBold(32, spacing: 4, color: tokens.textMuted),
        ),
      ],
    );
  }
}
