// presentation/mobile/modern_mobile_ui.dart
// ============================================================================
// STREAMZ — Modern Mobile UI (Brutalist Web Studio Edition - Edge to Edge)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/media_item.dart';
import '../client/client_viewmodel.dart';
import '../player/player_screen.dart';


class ModernMobileUIScreen extends StatefulWidget {
  const ModernMobileUIScreen({super.key});

  @override
  State<ModernMobileUIScreen> createState() => _ModernMobileUIScreenState();
}

class _ModernMobileUIScreenState extends State<ModernMobileUIScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final tokens = context.tokens;
    final allMedia = vm.remoteMedia;
    final stations = vm.stations;
    final continueWatching = vm.continueWatching;
    final videos = vm.videos;
    final audio = vm.audio;
    final images = vm.images;

    // Zero outer padding for edge-to-edge grids, minimal padding just for text readability
    const double hPad = 0.0;
    const double textPad = 16.0;

    final featuredItems = [...continueWatching, ...videos].take(5).toList();

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: allMedia.isEmpty
            ? const Center(child: _EmptyState())
            : CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Persistent Floating Top Bar (Dashboard Style)
            SliverAppBar(
              backgroundColor: tokens.surface1,
              floating: true,
              elevation: 0,
              pinned: true,
              titleSpacing: 0,
              leading: Actions(
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      Navigator.pop(context);
                      return null;
                    },
                  ),
                },
                child: Focus(
                  onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => Navigator.pop(context)),
                  child: IconButton(
                    icon: Icon(LucideIcons.arrowLeft, color: tokens.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              title: Text(
                'STREAMZ // STUDIO',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  letterSpacing: 4,
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              centerTitle: false,
              actions: [
                Actions(
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        _openSearch(context, allMedia);
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => _openSearch(context, allMedia)),
                    child: IconButton(
                      icon: Icon(LucideIcons.search, color: tokens.textSecondary, size: 20),
                      onPressed: () => _openSearch(context, allMedia),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
              ),
            ),

            // Featured Hero Slider
            if (featuredItems.isNotEmpty)
              SliverToBoxAdapter(
                child: _HeroSection(items: featuredItems, vm: vm, allItems: allMedia),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 100)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Live Stations
            if (stations.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _StationRail(stations: stations, vm: vm, hPad: hPad, textPad: textPad),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            // Continue Watching
            if (continueWatching.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _MobileContentRail(title: 'CONTINUE WATCHING', subTitle: 'PATH // ROOT/RESUME', items: continueWatching, showProgress: true, vm: vm, hPad: hPad, textPad: textPad),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            // Videos
            if (videos.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _MobileContentRail(title: 'VIDEO ARCHIVE', subTitle: 'PATH // ROOT/VIDEOS', items: videos, vm: vm, hPad: hPad, textPad: textPad),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            // Audio
            if (audio.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _MobileContentRail(title: 'AUDIO MATRIX', subTitle: 'PATH // ROOT/AUDIO', items: audio, vm: vm, hPad: hPad, textPad: textPad),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            // Images
            if (images.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _MobileContentRail(title: 'PHOTO DB', subTitle: 'PATH // ROOT/IMAGES', items: images, vm: vm, hPad: hPad, textPad: textPad),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
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
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO SLIDER SECTION (Industrial Style)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatefulWidget {
  final List<MediaItem> items;
  final ClientViewModel vm;
  final List<MediaItem> allItems;

  const _HeroSection({required this.items, required this.vm, required this.allItems});

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (_pageCtrl.hasClients) {
          int next = _currentPage + 1;
          if (next >= widget.items.length) next = 0;
          _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 0), curve: Curves.linear);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _play(BuildContext context, MediaItem item) {
    final idx = widget.allItems.indexOf(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(items: widget.allItems, startIndex: idx >= 0 ? idx : 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final thumbUrl = widget.vm.thumbnailUrl(item.id);

              return GestureDetector(
                onTap: () => _play(context, item),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                  ),
                  child: Column(
                    children: [
                      // Image Top
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: tokens.surface2,
                          child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: item.isAudio ? LucideIcons.music : LucideIcons.video),
                        ),
                      ),
                      // Data Bottom
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: tokens.surface1,
                          border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: tokens.textPrimary),
                              child: Text(
                                'PLAY',
                                style: GoogleFonts.dmMono(color: tokens.background, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STATUS // HIGHLIGHTED',
                                    style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 8, letterSpacing: 2),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.title.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Page Indicator Lines
          if (widget.items.length > 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                children: List.generate(
                  widget.items.length,
                      (index) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.only(right: 1),
                      color: _currentPage == index ? tokens.accent : tokens.background.withValues(alpha: 0.5),
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
// SQUARE BRUTALIST CONTENT RAIL
// ─────────────────────────────────────────────────────────────────────────────

class _MobileContentRail extends StatelessWidget {
  final String title;
  final String subTitle;
  final List<MediaItem> items;
  final bool showProgress;
  final double hPad;
  final double textPad;
  final ClientViewModel vm;

  const _MobileContentRail({required this.title, required this.subTitle, required this.items, required this.vm, required this.hPad, required this.textPad, this.showProgress = false});

  void _play(BuildContext context, MediaItem item) {
    final idx = items.indexOf(item);
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(items: items, startIndex: idx >= 0 ? idx : 0)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(textPad, 0, textPad, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 2),
              Text(
                subTitle.toUpperCase(),
                style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 2),
              ),
            ],
          ),
        ),
        Container(
          height: 140,
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            color: tokens.surface1,
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad), // Flush padding
            itemCount: items.length,
            itemBuilder: (_, i) => _MobileRailCard(
              item: items[i],
              size: 140,
              showProgress: showProgress,
              vm: vm,
              onTap: () => _play(context, items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileRailCard extends StatefulWidget {
  final MediaItem item;
  final double size;
  final bool showProgress;
  final ClientViewModel vm;
  final VoidCallback onTap;

  const _MobileRailCard({required this.item, required this.size, required this.showProgress, required this.vm, required this.onTap});

  @override
  State<_MobileRailCard> createState() => _MobileRailCardState();
}

class _MobileRailCardState extends State<_MobileRailCard> {
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final thumbUrl = widget.vm.thumbnailUrl(widget.item.id);

    return Focus(
      onFocusChange: (v) {
        setState(() => _isFocused = v);
        if (v) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          width: widget.size,
          decoration: BoxDecoration(
            color: _isFocused || _isPressed ? tokens.textPrimary : tokens.surface2,
            border: Border(right: BorderSide(color: tokens.border.withValues(alpha: 0.15))), // Only right border for flush continuous scroll
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poster (78%)
              Expanded(
                flex: 78,
                child: Container(
                  color: tokens.background,
                  child: NetworkImageFade(
                    url: thumbUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: widget.item.isAudio ? LucideIcons.music : LucideIcons.video,
                  ),
                ),
              ),
              // Progress Bar
              if (widget.showProgress && widget.item.isInProgress)
                Container(
                  height: 2,
                  alignment: Alignment.centerLeft,
                  color: tokens.border.withValues(alpha: 0.15),
                  child: FractionallySizedBox(
                    widthFactor: widget.item.watchProgress,
                    child: Container(color: _isFocused || _isPressed ? tokens.background : tokens.accent),
                  ),
                ),
              // Info (22%)
              Expanded(
                flex: 22,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                  ),
                  child: Text(
                    widget.item.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmMono(
                      color: _isFocused || _isPressed ? tokens.background : tokens.textSecondary,
                      fontSize: 10,
                      fontWeight: (_isFocused || _isPressed) ? FontWeight.bold : FontWeight.normal,
                      letterSpacing: 1,
                    ),
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
// LIVE STATION RAIL
// ─────────────────────────────────────────────────────────────────────────────

class _StationRail extends StatelessWidget {
  final List<Map<String, dynamic>> stations;
  final ClientViewModel vm;
  final double hPad;
  final double textPad;

  const _StationRail({required this.stations, required this.vm, required this.hPad, required this.textPad});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(textPad, 0, textPad, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NETWORK BROADCASTS', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text('PATH // ROOT/LIVE', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 9, letterSpacing: 2)),
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
            padding: EdgeInsets.symmetric(horizontal: hPad), // Flush padding
            itemCount: stations.length,
            itemBuilder: (_, i) => _StationCard(station: stations[i], vm: vm),
          ),
        ),
      ],
    );
  }
}

class _StationCard extends StatefulWidget {
  final Map<String, dynamic> station;
  final ClientViewModel vm;

  const _StationCard({required this.station, required this.vm});

  @override
  State<_StationCard> createState() => _StationCardState();
}

class _StationCardState extends State<_StationCard> {
  bool _focused = false;

  void _tuneIn() async {
    final res = await widget.vm.joinStation(widget.station['id']);
    if (res != null && mounted) {
      final items = (res['playlist'] as List?)?.map((e) => MediaItem.fromJson(e)).toList() ?? [MediaItem.fromJson(res['item'])];
      final startIndex = res['itemIndex'] as int? ?? 0;
      final offsetMs = res['positionMs'] as int;
      final isPaused = res['isPaused'] as bool? ?? false;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PlayerScreen(
                    items: items,
                    startIndex: startIndex,
                    isPathBased: false,
                    startOffset: Duration(milliseconds: offsetMs),
                    autoPlay: !isPaused,
                  )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final nowPlaying = widget.station['nowPlaying'];
    final title = widget.station['name'].toString().toUpperCase();
    final itemTitle = nowPlaying != null ? nowPlaying['item']['title'].toString().toUpperCase() : 'AWAITING SIGNAL';

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, _tuneIn),
      child: GestureDetector(
        onTap: _tuneIn,
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _focused ? tokens.textPrimary : tokens.surface2,
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
                    child: Text(title, style: GoogleFonts.barlowCondensed(color: _focused ? tokens.background : tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1), maxLines: 1),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(border: Border.all(color: _focused ? tokens.background : tokens.textPrimary)),
                    child: Text('LIVE', style: GoogleFonts.dmMono(fontSize: 9, fontWeight: FontWeight.bold, color: _focused ? tokens.background : tokens.textPrimary)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STATUS // NOW PLAYING', style: GoogleFonts.dmMono(fontSize: 8, color: _focused ? tokens.background.withValues(alpha:0.5) : tokens.textMuted, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(itemTitle, style: GoogleFonts.dmMono(fontSize: 10, color: _focused ? tokens.background : tokens.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH GRID (4-Column Brutalist Layout)
// ─────────────────────────────────────────────────────────────────────────────

class _MobileSearchScreen extends StatefulWidget {
  final List<MediaItem> allMedia;
  const _MobileSearchScreen({required this.allMedia});

  @override
  State<_MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<_MobileSearchScreen> {
  String _query = '';
  final _ctrl = TextEditingController();

  List<MediaItem> get _results {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return widget.allMedia.where((m) => m.title.toLowerCase().contains(q) || m.folder.toLowerCase().contains(q)).take(50).toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _play(MediaItem item) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(items: [item], startIndex: 0)));
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Search Bar
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: tokens.surface1,
                border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.arrowLeft, color: tokens.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('CMD>', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 12)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 12, letterSpacing: 1),
                      cursorColor: tokens.textPrimary,
                      decoration: InputDecoration(
                        hintText: 'SEARCH QUERY...',
                        hintStyle: TextStyle(color: tokens.textMuted),
                        border: InputBorder.none,
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                          icon: Icon(LucideIcons.x, color: tokens.textMuted, size: 18),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                        )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            // Results Grid
            Expanded(
              child: _query.isEmpty
                  ? Center(
                child: Container(
                  margin: EdgeInsets.zero, // Outer padding removed
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                  decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15), style: BorderStyle.solid)),
                  child: Text('AWAITING SIGNAL // CMD READY', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 4)),
                ),
              )
                  : results.isEmpty
                  ? Center(
                child: Container(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                  decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15), style: BorderStyle.solid)),
                  child: Text('0 SIGNALS FOUND', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 4)),
                ),
              )
                  : Container(
                decoration: BoxDecoration(color: tokens.border.withValues(alpha: 0.15)),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _MobileRailCard(
                          item: results[i],
                          size: double.infinity,
                          showProgress: true,
                          vm: vm,
                          onTap: () => _play(results[i]),
                        ),
                        childCount: results.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      margin: EdgeInsets.zero, // Outer padding removed
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15), style: BorderStyle.solid)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SIGNAL ERROR // DISCONNECTED', style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 4)),
        ],
      ),
    );
  }
}
