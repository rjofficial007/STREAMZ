// presentation/mobile/modern_mobile_ui.dart
// ============================================================================
// STREAMZ — Premium Mobile Home
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
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/domain/services/queue_service.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/client/media_title_search.dart';
import 'package:streamz/presentation/client/widgets/client_connection_notice.dart';
import 'package:streamz/presentation/client/widgets/client_library_state.dart';
import 'package:streamz/presentation/mobile/widgets/mobile_content_rail.dart';
import 'package:streamz/presentation/mobile/widgets/mobile_hero_section.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_live_station_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
import 'package:streamz/presentation/shared/media_details_text.dart';
import 'package:streamz/presentation/shared/media_favorite_button.dart';

class ModernMobileUIScreen extends StatefulWidget {
  const ModernMobileUIScreen({super.key});

  @override
  State<ModernMobileUIScreen> createState() => _ModernMobileUIScreenState();
}

class _ModernMobileUIScreenState extends State<ModernMobileUIScreen> {
  @override
  void initState() {
    super.initState();
    // Support all orientations for mobile.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Reset to portrait on exit.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final tokens = context.tokens;
    final allMedia = vm.remoteMedia;
    final width = MediaQuery.sizeOf(context).width;
    final contentPad = width > 900 ? (width - 900) / 2 + 16 : 16.0;

    // Feature one item at a time and remove it from its shelf to avoid
    // repeating the same media immediately below the hero.
    final continueIds = vm.continueWatching.map((item) => item.id).toSet();
    final featuredItems = vm.videos
        .where((item) => !continueIds.contains(item.id))
        .take(1)
        .toList();
    final featuredIds = featuredItems.map((item) => item.id).toSet();
    final continueItems = vm.continueWatching;
    final favoriteItems = vm.favoriteItems;
    final videoItems = vm.videos
        .where((item) => !featuredIds.contains(item.id))
        .toList();

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(context, tokens),
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: MobileHeroSection(
                          items: featuredItems,
                          vm: vm,
                          allItems: allMedia,
                        ),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              if (vm.stations.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _StationRail(
                    stations: vm.stations,
                    vm: vm,
                    textPad: contentPad,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              if (continueItems.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: MobileContentRail(
                    title: AppStrings.continueWatching,
                    items: continueItems,
                    showProgress: true,
                    vm: vm,
                    textPad: contentPad,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              if (favoriteItems.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: MobileContentRail(
                    title: AppStrings.favorites,
                    items: favoriteItems,
                    vm: vm,
                    textPad: contentPad,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              if (videoItems.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: MobileContentRail(
                    title: AppStrings.videoArchive,
                    items: videoItems,
                    vm: vm,
                    textPad: contentPad,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              if (vm.images.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: MobileContentRail(
                    title: AppStrings.photoDb,
                    items: vm.images,
                    vm: vm,
                    textPad: contentPad,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              if (vm.audio.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: MobileContentRail(
                    title: AppStrings.audioMatrix,
                    items: vm.audio,
                    vm: vm,
                    textPad: contentPad,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              SliverToBoxAdapter(child: _SharedQueueRail(textPad: contentPad)),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, StreamzThemeExtension tokens) {
    return AppSliverAppBar(
      floating: true,
      pinned: true,
      titleSpacing: 0,
      leading: AppBackButton(onPressed: () => context.pop()),
      title: Text(
        AppStrings.appTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.display(20, spacing: 4, color: tokens.textPrimary),
      ),
      actions: [
        IconButton(
          tooltip: AppStrings.search,
          icon: const Icon(AppIcons.search, color: DS.textSecondary, size: 20),
          onPressed: () =>
              _openSearch(context, context.read<ClientViewModel>().remoteMedia),
        ),
        PopupMenuButton<String>(
          tooltip: 'More options',
          icon: const Icon(Icons.more_horiz, color: DS.textSecondary),
          onSelected: (value) {
            if (value == 'relay') context.push('/relay');
            if (value == 'settings') context.push('/settings');
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'relay',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(AppIcons.relay),
                title: Text('Remote relay'),
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(AppIcons.settings),
                title: Text('Appearance'),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _openSearch(BuildContext context, List<MediaItem> allMedia) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ChangeNotifierProvider.value(
          value: context.read<ClientViewModel>(),
          child: _MobileSearchScreen(allMedia: allMedia),
        ),
        transitionsBuilder: (_, a, _, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }
}

class _SharedQueueRail extends StatelessWidget {
  const _SharedQueueRail({required this.textPad});

  final double textPad;

  @override
  Widget build(BuildContext context) {
    final queueSvc = context.watch<QueueService>();
    final queue = queueSvc.queue;
    final vm = context.read<ClientViewModel>();
    final tokens = context.tokens;
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.68)
        .clamp(240.0, 320.0)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(textPad, 0, textPad, DS.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.sharedQueue,
                style: AppTextStyles.heading(
                  22,
                  spacing: -0.4,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: DS.s4),
              Text(
                AppStrings.voteForNextSignal,
                style: AppTextStyles.text(12, color: tokens.textMuted),
              ),
            ],
          ),
        ),
        if (queue.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: textPad),
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s16,
                  vertical: DS.s12,
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.surface2,
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: DS.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.queueEmpty,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: DS.s4),
                          Text(
                            'Add media to vote on what plays next.',
                            style: AppTextStyles.supporting.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 156,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: textPad),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final item = queue[index];
                return Padding(
                  padding: const EdgeInsets.only(right: DS.s12, bottom: DS.s4),
                  child: SizedBox(
                    width: cardWidth,
                    child: AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(DS.s16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.media.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: tokens.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: DS.s8),
                                  Text(
                                    '${AppStrings.by} ${item.addedBy}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.supporting.copyWith(
                                      color: tokens.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: DS.s8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Upvote ${item.media.title}',
                                  icon: const Icon(AppIcons.arrowUp),
                                  onPressed: () => vm.sendQueueCommand('vote', {
                                    'id': item.media.id,
                                    'delta': 1,
                                  }),
                                ),
                                Text(
                                  '${item.votes}',
                                  style: AppTextStyles.body.copyWith(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Downvote ${item.media.title}',
                                  icon: const Icon(AppIcons.arrowDown),
                                  onPressed: () => vm.sendQueueCommand('vote', {
                                    'id': item.media.id,
                                    'delta': -1,
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _StationRail extends StatelessWidget {
  const _StationRail({
    required this.stations,
    required this.vm,
    required this.textPad,
  });
  final List<BroadcastStation> stations;
  final ClientViewModel vm;
  final double textPad;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(textPad, 0, textPad, DS.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.networkBroadcasts,
                style: AppTextStyles.heading(
                  22,
                  spacing: -0.4,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: DS.s4),
              Text(
                AppStrings.pathLive,
                style: AppTextStyles.text(12, color: tokens.textMuted),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 156,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: textPad),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final station = stations[index];
              return Padding(
                padding: const EdgeInsets.only(right: DS.s12),
                child: AppLiveStationCard(
                  width: 240,
                  height: 140,
                  title: station.name,
                  trackTitle:
                      station.nowPlaying?.item.title ??
                      AppStrings.awaitingSignal,
                  liveLabel: AppStrings.live,
                  nowPlayingLabel: AppStrings.statusNowPlaying,
                  onTap: () => unawaited(_tuneIn(context, station)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _tuneIn(BuildContext context, BroadcastStation station) async {
    final res = await vm.joinStation(station.id);
    if (res == null || !context.mounted) return;
    unawaited(
      context.push(
        '/player',
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

class _MobileSearchScreen extends StatefulWidget {
  const _MobileSearchScreen({required this.allMedia});
  final List<MediaItem> allMedia;

  @override
  State<_MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<_MobileSearchScreen> {
  String _query = '';
  final _ctrl = TextEditingController();
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
  void dispose() {
    _searchDebounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ClientViewModel>();
    final tokens = context.tokens;
    final results = _results;

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Row(
                children: [
                  AppBackButton(onPressed: () => context.pop()),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: AppTextStyles.text(14, color: tokens.textPrimary),
                      decoration: const InputDecoration(
                        hintText: AppStrings.searchSignalHint,
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
                          padding: const EdgeInsets.fromLTRB(
                            DS.s16,
                            DS.s8,
                            DS.s16,
                            DS.s4,
                          ),
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
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      (MediaQuery.sizeOf(context).width /
                                              (160 *
                                                  MediaQuery.textScalerOf(
                                                    context,
                                                  ).scale(14) /
                                                  14))
                                          .floor()
                                          .clamp(1, 6),
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.75,
                                ),
                            itemCount: results.length,
                            itemBuilder: (ctx, i) {
                              final item = results[i];
                              return AppCard(
                                onTap: () => context.push(
                                  '/player',
                                  extra: {'items': results, 'startIndex': i},
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Stack(
                                    children: [
                                      Column(
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: AspectRatio(
                                                aspectRatio: 1,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        DS.radius(12),
                                                      ),
                                                  child: NetworkImageFade(
                                                    url: vm.thumbnailUrl(
                                                      item.id,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.caption.copyWith(
                                              color: tokens.textPrimary,
                                            ),
                                          ),
                                          MediaDetailsText(item: item),
                                        ],
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: MediaFavoriteButton(
                                          item: item,
                                          viewModel: vm,
                                          tvFocus: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
