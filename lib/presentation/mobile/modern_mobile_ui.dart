// presentation/mobile/modern_mobile_ui.dart
// ============================================================================
// STREAMZ — Modern Mobile UI (Netflix Style with Persistent AppBar)
// ============================================================================

import 'dart:async'; // Added for the slider Timer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
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
    final allMedia = vm.remoteMedia;
    final stations = vm.stations;
    final continueWatching = vm.continueWatching;
    final videos = vm.videos;
    final audio = vm.audio;
    final images = vm.images;

    final isMobile = DS.isMobile(context);
    final hPad = isMobile ? DS.s16 : DS.s32;

    // Grab up to 5 items to feature in the Hero Slider
    final featuredItems = [...continueWatching, ...videos].take(5).toList();

    return Scaffold(
      backgroundColor: DS.bg,
      body: SafeArea(
        child: allMedia.isEmpty
            ? const Center(child: _EmptyState())
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Persistent Floating Top Bar
                  SliverAppBar(
                    backgroundColor: DS.bg.withValues(alpha: 0.95),
                    floating: true,
                    elevation: 0,
                    pinned: false,
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
                          icon: const Icon(LucideIcons.arrowLeft, color: DS.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    title: Text(
                      'STREAMZ',
                      style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 14, letterSpacing: 4, color: DS.accent, fontWeight: FontWeight.bold),
                    ),
                    centerTitle: false,
                    actions: [
                      Center(
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF30D158),
                                boxShadow: [BoxShadow(color: Color(0xFF30D158), blurRadius: 4)],
                              ),
                            ),
                            const SizedBox(width: DS.s8),
                            Text(vm.targetIp, style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
                            const SizedBox(width: DS.s16),
                          ],
                        ),
                      ),
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
                            icon: const Icon(LucideIcons.search, color: DS.textPrimary),
                            onPressed: () => _openSearch(context, allMedia),
                          ),
                        ),
                      ),
                      SizedBox(width: hPad - 8),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(color: DS.borderDefault, height: 1),
                    ),
                  ),

                  // Featured Hero Slider (16:9 Aspect Ratio)
                  if (featuredItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _HeroSection(items: featuredItems, vm: vm, allItems: allMedia),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),

                  const SliverToBoxAdapter(child: SizedBox(height: DS.s24)),

                  // Live Stations
                  if (stations.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _StationRail(stations: stations, vm: vm, hPad: hPad),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: DS.s24)),
                  ],

                  // Continue Watching
                  if (continueWatching.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _MobileContentRail(title: 'CONTINUE WATCHING', items: continueWatching, showProgress: true, vm: vm, hPad: hPad),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: DS.s24)),
                  ],

                  // Videos
                  if (videos.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _MobileContentRail(title: 'VIDEOS', items: videos, vm: vm, hPad: hPad),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: DS.s24)),
                  ],

                  // Audio
                  if (audio.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _MobileContentRail(title: 'AUDIO', items: audio, isSquare: true, vm: vm, hPad: hPad),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: DS.s24)),
                  ],

                  // Images
                  if (images.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _MobileContentRail(title: 'PHOTOS', items: images, vm: vm, hPad: hPad),
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
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<ClientViewModel>(),
          child: _MobileSearchScreen(allMedia: allMedia),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO SLIDER SECTION (16:9 Aspect Ratio)
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
    // Auto-slide every 6 seconds if there is more than 1 featured item
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (_pageCtrl.hasClients) {
          int next = _currentPage + 1;
          if (next >= widget.items.length) next = 0;
          _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
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
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final thumbUrl = widget.vm.thumbnailUrl(item.id);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Hero Image
                  NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: item.isAudio ? LucideIcons.music : LucideIcons.video),

                  // Gradient Fade to Background Color
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, DS.bg.withValues(alpha: 0.1), DS.bg.withValues(alpha: 0.7), DS.bg],
                        stops: const [0.0, 0.4, 0.8, 1.0],
                      ),
                    ),
                  ),

                  // Content Details & Actions
                  Positioned(
                    bottom: 24, // Lifted slightly to make room for indicator dots
                    left: 0,
                    right: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'FEATURED',
                              style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.accent, letterSpacing: 2, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(color: DS.textMuted, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(item.type.toUpperCase(), style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.textMuted)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Title
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            item.title.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: AppTheme.theme.textTheme.displayMedium?.copyWith(fontSize: 24, height: 1.1),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Actions (Play / Info)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _HeroButton(icon: LucideIcons.play, label: 'PLAY', isPrimary: true, onTap: () => _play(context, item)),
                            const SizedBox(width: 12),
                            _HeroButton(
                              icon: LucideIcons.info,
                              label: 'INFO',
                              isPrimary: false,
                              onTap: () {}, // Future expansion
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Page Indicator Dots
          if (widget.items.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 4,
                    width: _currentPage == index ? 16 : 4, // Active dot expands to a pill
                    decoration: BoxDecoration(color: _currentPage == index ? DS.accent : Colors.white30, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _HeroButton({required this.icon, required this.label, required this.isPrimary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap();
            return null;
          },
        ),
      },
      child: Focus(
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, onTap),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 110,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isPrimary ? Colors.white : DS.surface2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: DS.borderDefault),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isPrimary ? Colors.black : Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTheme.theme.textTheme.labelMedium?.copyWith(color: isPrimary ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE CONTENT RAIL
// ─────────────────────────────────────────────────────────────────────────────

class _MobileContentRail extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final bool showProgress;
  final bool isSquare;
  final bool isPoster;
  final double hPad;
  final ClientViewModel vm;

  const _MobileContentRail({required this.title, required this.items, required this.vm, required this.hPad, this.showProgress = false, this.isSquare = false, this.isPoster = false});

  void _play(BuildContext context, MediaItem item) {
    final idx = items.indexOf(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(items: items, startIndex: idx >= 0 ? idx : 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = DS.isMobile(context);

    // Adjust dimensions based on desired style (Poster vs Thumbnail vs Square)
    double cardW;
    double cardH;

    if (isPoster) {
      cardW = isMobile ? 110.0 : 160.0;
      cardH = isMobile ? 160.0 : 240.0; // Taller aspect ratio
    } else if (isSquare) {
      cardW = isMobile ? 120.0 : 160.0;
      cardH = isMobile ? 120.0 : 160.0;
    } else {
      // Standard 16:9 Thumbnail
      cardW = isMobile ? 160.0 : 240.0;
      cardH = isMobile ? 90.0 : 135.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
          child: Text(
            title,
            style: AppTheme.theme.textTheme.labelMedium?.copyWith(letterSpacing: 1, fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: cardH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: items.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: DS.s8),
              child: _MobileRailCard(item: items[i], width: cardW, height: cardH, showProgress: showProgress, vm: vm, onTap: () => _play(context, items[i])),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileRailCard extends StatefulWidget {
  final MediaItem item;
  final double width;
  final double height;
  final bool showProgress;
  final ClientViewModel vm;
  final VoidCallback onTap;

  const _MobileRailCard({required this.item, required this.width, required this.height, required this.showProgress, required this.vm, required this.onTap});

  @override
  State<_MobileRailCard> createState() => _MobileRailCardState();
}

class _MobileRailCardState extends State<_MobileRailCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = widget.vm.thumbnailUrl(widget.item.id);

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
          setState(() => _isFocused = v);
          if (v) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 250));
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTapDown: (_) => _scaleCtrl.forward(),
          onTapUp: (_) {
            _scaleCtrl.reverse();
            widget.onTap();
          },
          onTapCancel: () => _scaleCtrl.reverse(),
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: DS.surface1,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _isFocused ? DS.accent : Colors.transparent, width: _isFocused ? 2 : 0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.isAudio ? LucideIcons.music : LucideIcons.video),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC000000)], stops: [0.5, 1.0]),
                      ),
                    ),

                    Positioned(
                      bottom: DS.s8,
                      left: DS.s8,
                      right: DS.s8,
                      child: Text(
                        widget.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 11, height: 1.2, fontWeight: FontWeight.bold),
                      ),
                    ),

                    if (widget.showProgress && widget.item.isInProgress)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(value: widget.item.watchProgress, backgroundColor: Colors.transparent, valueColor: const AlwaysStoppedAnimation(Colors.red), minHeight: 3),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(LucideIcons.wifiHigh, size: 48, color: DS.textMuted),
        const SizedBox(height: DS.s16),
        Text('NO SIGNAL DETECTED', style: AppTheme.theme.textTheme.titleMedium?.copyWith(color: DS.textMuted)),
        const SizedBox(height: DS.s8),
        Text('LIBRARY EMPTY OR SYNCING', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 2)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATION RAIL
// ─────────────────────────────────────────────────────────────────────────────

class _StationRail extends StatelessWidget {
  final List<Map<String, dynamic>> stations;
  final ClientViewModel vm;
  final double hPad;

  const _StationRail({required this.stations, required this.vm, required this.hPad});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
          child: Row(
            children: [
              const Icon(LucideIcons.radio, color: DS.accent, size: 16),
              const SizedBox(width: 8),
              Text(
                'LIVE BROADCASTS',
                style: AppTheme.theme.textTheme.labelMedium?.copyWith(letterSpacing: 1, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: stations.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: DS.s8),
              child: _StationCard(station: stations[i], vm: vm),
            ),
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
      final item = MediaItem.fromJson(res['item']);
      final offsetMs = res['positionMs'] as int;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            items: [item],
            startIndex: 0,
            isPathBased: true,
            startOffset: Duration(milliseconds: offsetMs),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowPlaying = widget.station['nowPlaying'];
    final title = widget.station['name'].toString().toUpperCase();
    final itemTitle = nowPlaying != null ? nowPlaying['item']['title'].toString().toUpperCase() : 'AWAITING SIGNAL';

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, _tuneIn),
      child: GestureDetector(
        onTap: _tuneIn,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 200,
          decoration: BoxDecoration(
            color: _focused ? DS.surface3 : DS.surface1,
            border: Border.all(color: _focused ? DS.accent : DS.borderDefault),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(title, style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    color: Colors.redAccent,
                    child: Text('LIVE', style: GoogleFonts.dmMono(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NOW PLAYING', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 8, color: DS.textMuted)),
                  const SizedBox(height: 2),
                  Text(itemTitle, style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 10, color: DS.accent), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final results = _results;
    final isMobile = DS.isMobile(context);
    final hPad = isMobile ? DS.s16 : DS.s32;

    return Scaffold(
      backgroundColor: DS.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(8, 16, hPad, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DS.borderDefault)),
              ),
              child: Row(
                children: [
                  Actions(
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
                        icon: const Icon(LucideIcons.arrowLeft, color: DS.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 14, letterSpacing: 1),
                      decoration: InputDecoration(
                        hintText: 'SEARCH MATRIX...',
                        hintStyle: const TextStyle(color: DS.textMuted),
                        border: InputBorder.none,
                        suffixIcon: _query.isNotEmpty
                            ? Actions(
                                actions: {
                                  ActivateIntent: CallbackAction<ActivateIntent>(
                                    onInvoke: (_) {
                                      _ctrl.clear();
                                      setState(() => _query = '');
                                      return null;
                                    },
                                  ),
                                },
                                child: Focus(
                                  onKeyEvent: (_, ev) => handleTVSelectKey(ev, () {
                                    _ctrl.clear();
                                    setState(() => _query = '');
                                  }),
                                  child: IconButton(
                                    icon: const Icon(LucideIcons.x, color: DS.textMuted, size: 18),
                                    onPressed: () {
                                      _ctrl.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? Center(child: Text('AWAITING QUERY', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 2)))
                  : results.isEmpty
                  ? Center(child: Text('NO RESULTS FOR "${_query.toUpperCase()}"', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 2)))
                  : GridView.builder(
                      padding: EdgeInsets.all(hPad),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, childAspectRatio: 16 / 9, crossAxisSpacing: DS.s8, mainAxisSpacing: DS.s8),
                      itemCount: results.length,
                      itemBuilder: (_, i) => _MobileRailCard(item: results[i], width: double.infinity, height: double.infinity, showProgress: true, vm: vm, onTap: () => _play(results[i])),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
