// presentation/mobile/modern_mobile_ui.dart
// ============================================================================
// STREAMZ — Modern Mobile UI (Brutalist Web Studio Edition - Edge to Edge)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import 'package:streamz/presentation/mobile/widgets/mobile_content_rail.dart';
import 'package:streamz/presentation/mobile/widgets/mobile_hero_section.dart';

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
      DeviceOrientation.landscapeRight
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
    
    // Feature recent content in the Hero Section.
    final featuredItems = [...vm.continueWatching, ...vm.videos].take(5).toList();

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: allMedia.isEmpty
            ? const Center(child: _EmptyState())
            : CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(context, tokens),

            if (featuredItems.isNotEmpty)
              SliverToBoxAdapter(
                child: MobileHeroSection(items: featuredItems, vm: vm, allItems: allMedia),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 100)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            if (vm.stations.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _StationRail(stations: vm.stations, vm: vm),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            if (vm.continueWatching.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: MobileContentRail(
                  title: AppStrings.continueWatching, 
                  subTitle: AppStrings.pathResume, 
                  items: vm.continueWatching, 
                  showProgress: true, 
                  vm: vm, 
                  textPad: 16.0
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            if (vm.videos.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: MobileContentRail(
                  title: AppStrings.videoArchive, 
                  subTitle: AppStrings.pathVideos, 
                  items: vm.videos, 
                  vm: vm, 
                  textPad: 16.0
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            if (vm.images.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: MobileContentRail(
                  title: AppStrings.photoDb, 
                  subTitle: AppStrings.pathImages, 
                  items: vm.images, 
                  vm: vm, 
                  textPad: 16.0
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            if (vm.audio.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: MobileContentRail(
                  title: AppStrings.audioMatrix, 
                  subTitle: AppStrings.pathAudio, 
                  items: vm.audio, 
                  vm: vm, 
                  textPad: 16.0
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            const SliverToBoxAdapter(child: _SharedQueueRail()),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, StreamzThemeExtension tokens) => SliverAppBar(
      backgroundColor: tokens.surface1,
      floating: true,
      elevation: 0,
      pinned: true,
      titleSpacing: 0,
      leading: IconButton(
        tooltip: AppStrings.back,
        icon: const Icon(AppIcons.back, color: DS.textSecondary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        AppStrings.streamzStudio,
        style: AppTextStyles.barlowBlack(20, spacing: 4, color: tokens.textPrimary),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          tooltip: AppStrings.search,
          icon: const Icon(AppIcons.search, color: DS.textSecondary, size: 20),
          onPressed: () => _openSearch(context, context.read<ClientViewModel>().remoteMedia),
        ),
        IconButton(
          tooltip: AppStrings.relay,
          icon: const Icon(AppIcons.relay, color: DS.textSecondary, size: 20),
          onPressed: () => context.push('/relay'),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
      ),
    );

  void _openSearch(BuildContext context, List<MediaItem> allMedia) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ChangeNotifierProvider.value(
          value: context.read<ClientViewModel>(),
          child: _MobileSearchScreen(allMedia: allMedia),
        ),
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }
}

class _SharedQueueRail extends StatelessWidget {
  const _SharedQueueRail();

  @override
  Widget build(BuildContext context) {
    final queueSvc = context.watch<QueueService>();
    final vm = context.read<ClientViewModel>();
    final tokens = context.tokens;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.sharedQueue, style: AppTextStyles.barlowBold(24, spacing: 2, color: tokens.textPrimary)),
              const SizedBox(height: 2),
              Text(AppStrings.voteForNextSignal, style: AppTextStyles.mono(9, spacing: 2, color: tokens.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 100,
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            color: tokens.surface1,
          ),
          child: queueSvc.queue.isEmpty
              ? Center(child: Text(AppStrings.queueEmpty, style: AppTextStyles.labelSm))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: queueSvc.queue.length,
                  itemBuilder: (_, i) {
                    final qItem = queueSvc.queue[i];
                    return Container(
                      width: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border(right: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(qItem.media.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMd),
                                Text('${AppStrings.by} ${qItem.addedBy}', style: AppTextStyles.labelSm),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(AppIcons.arrowUp, size: 16),
                                onPressed: () => vm.sendQueueCommand('vote', {'id': qItem.media.id, 'delta': 1}),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Text('${qItem.votes}', style: AppTextStyles.labelMd),
                              IconButton(
                                icon: const Icon(AppIcons.arrowDown, size: 16),
                                onPressed: () => vm.sendQueueCommand('vote', {'id': qItem.media.id, 'delta': -1}),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
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

  const _StationRail({required this.stations, required this.vm});
  final List<BroadcastStation> stations;
  final ClientViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.networkBroadcasts, style: AppTextStyles.barlowBold(24, spacing: 2, color: tokens.textPrimary)),
              const SizedBox(height: 2),
              Text(AppStrings.pathLive, style: AppTextStyles.mono(9, spacing: 2, color: tokens.textMuted)),
            ],
          ),
        ),
        Container(
          height: 100,
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            color: tokens.surface1,
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: stations.length,
            itemBuilder: (_, i) => _StationCard(station: stations[i], vm: vm),
          ),
        ),
      ],
    );
  }
}

class _StationCard extends StatefulWidget {

  const _StationCard({required this.station, required this.vm});
  final BroadcastStation station;
  final ClientViewModel vm;

  @override
  State<_StationCard> createState() => _StationCardState();
}

class _StationCardState extends State<_StationCard> {
  bool _isPressed = false;

  Future<void> _tuneIn() async {
    final res = await widget.vm.joinStation(widget.station.id);
    if (res != null && mounted) {
      unawaited(context.push('/player', extra: {
        'items': res.playlist,
        'startIndex': res.itemIndex,
        'isPathBased': false,
        'startOffset': res.position,
        'autoPlay': !res.isPaused,
      }));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final nowPlaying = widget.station.nowPlaying;
    final title = widget.station.name.toUpperCase();
    final itemTitle = nowPlaying != null ? nowPlaying.item.title.toUpperCase() : AppStrings.awaitingSignal;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _tuneIn();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isPressed ? tokens.textPrimary : tokens.surface2,
          border: Border(right: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title, style: AppTextStyles.barlowBold(18, spacing: 1, color: _isPressed ? tokens.background : tokens.textPrimary), maxLines: 1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: _isPressed ? tokens.background : tokens.textPrimary)),
                  child: Text(AppStrings.live, style: AppTextStyles.mono(9, weight: FontWeight.bold, color: _isPressed ? tokens.background : tokens.textPrimary)),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.statusNowPlaying, style: AppTextStyles.mono(8, spacing: 1, color: _isPressed ? tokens.background.withValues(alpha:0.5) : tokens.textMuted)),
                const SizedBox(height: 4),
                Text(itemTitle, style: AppTextStyles.mono(10, color: _isPressed ? tokens.background : tokens.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
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

  List<MediaItem> get _results {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return widget.allMedia.where((m) => m.title.toLowerCase().contains(q)).take(50).toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ClientViewModel>();
    final tokens = context.tokens;
    final results = _results;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
              child: Row(
                children: [
                  IconButton(icon: const Icon(LucideIcons.arrowLeft), onPressed: () => context.pop()),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: AppTextStyles.mono(14, color: tokens.textPrimary),
                      decoration: const InputDecoration(hintText: AppStrings.searchSignalHint, border: InputBorder.none),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty 
                  ? Center(child: Text(AppStrings.noSignals, style: AppTextStyles.mono(12, color: tokens.textMuted)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 1, mainAxisSpacing: 1),
                      itemCount: results.length,
                      itemBuilder: (ctx, i) => GestureDetector(
                        onTap: () => context.push('/player', extra: {'items': results, 'startIndex': i}),
                        child: NetworkImageFade(url: vm.thumbnailUrl(results[i].id), fit: BoxFit.cover),
                      ),
                    ),
            ),
          ],
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
        const Icon(AppIcons.wifiOff, size: 48, color: DS.textMuted),
        const SizedBox(height: 16),
        Text(AppStrings.signalLost, style: AppTextStyles.mono(12, spacing: 4, color: tokens.textMuted)),
      ],
    );
  }
}
