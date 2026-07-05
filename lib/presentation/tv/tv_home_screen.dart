// presentation/tv/tv_home_screen.dart
// ============================================================================
// STREAMZ — TV Home Screen (Brutalist Web Studio Edition)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/models/media_item.dart';
import '../client/client_viewmodel.dart';
import '../shared/atmospheric_background.dart';
import 'tv_player_screen.dart';

// --- Web UI Color Palette & Styles ---
// DEPRECATED: Use context.tokens instead
const Color kWebBlack = DS.bg;
const Color kWebSurface = DS.surface1;
const Color kWebSurface2 = DS.surface2;
const Color kWebWhite = DS.accent;
final Color kWebBorder = DS.borderDefault;
final Color kWebTextMuted = DS.textMuted;
final Color kWebText = DS.textSecondary;


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
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight, DeviceOrientation.portraitUp]);
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

    // Dynamic TV Scaling constraints
    final size = MediaQuery.sizeOf(context);
    const double safePad = 0; // Removed for edge-to-edge look
    final double sidePadding = (size.width * 0.03).clamp(16.0, 48.0);
    final vSpacing = (size.height * 0.03).clamp(16.0, 40.0);

    // Grab up to 5 items to feature in the Hero Slider
    final featuredItems = [...continueWatching, ...videos].take(5).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: kWebBlack,
        extendBodyBehindAppBar: true,
        body: AtmosphericBackground(
          child: allMedia.isEmpty
              ? const Center(child: _EmptyState())
              : CustomScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(), // Prevent bounce on TVs
                slivers: [
                  // Persistent TV Top Bar
                  SliverAppBar(
                    backgroundColor: _isScrolled ? kWebSurface : Colors.transparent,
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
                              Navigator.pop(context);
                              return null;
                            },
                          ),
                        },
                        child: Focus(
                          onFocusChange: (f) {
                            if (f) Scrollable.ensureVisible(context, alignment: 0.0, duration: const Duration(milliseconds: 250));
                          },
                          onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => Navigator.pop(context)),
                          child: IconButton(
                            icon: Icon(LucideIcons.arrowLeft, color: kWebWhite, size: (size.width * 0.015).clamp(20.0, 28.0)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      'STREAMZ // STUDIO',
                      style: GoogleFonts.barlowCondensed(fontSize: (size.width * 0.015).clamp(18.0, 28.0), letterSpacing: 4, color: kWebWhite, fontWeight: FontWeight.w900),
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
                              style: GoogleFonts.dmMono(color: kWebText, fontSize: (size.width * 0.008).clamp(9.0, 12.0)),
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
                                _openSearch(context, allMedia);
                                return null;
                              },
                            ),
                          },
                          child: Focus(
                            onFocusChange: (f) {
                              if (f) Scrollable.ensureVisible(context, alignment: 0.0, duration: const Duration(milliseconds: 250));
                            },
                            onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => _openSearch(context, allMedia)),
                            child: IconButton(
                              icon: Icon(LucideIcons.search, color: kWebWhite, size: (size.width * 0.015).clamp(20.0, 28.0)),
                              onPressed: () => _openSearch(context, allMedia),
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
                        child: Container(color: kWebBorder, height: 1),
                      ),
                    ),
                  ),

                  // Hero Section (Fills 75% of screen height)
                  if (featuredItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: size.height * 0.75,
                        width: double.infinity,
                        child: _HeroSection(items: featuredItems, vm: vm, allItems: allMedia),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),

                  SliverToBoxAdapter(child: SizedBox(height: vSpacing)),

                  // Live Stations
                  if (stations.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _TVStationRail(stations: stations, railIndex: 0, focusedRail: _railFocus, onRailFocus: (i) => setState(() => _railFocus = i), vm: vm, safePad: safePad),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
                  ],

                  // Continue Watching
                  if (continueWatching.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _TVContentRail(
                        title: 'CONTINUE WATCHING',
                        subTitle: 'PATH // ROOT/RESUME',
                        items: continueWatching,
                        showProgress: true,
                        railIndex: stations.isNotEmpty ? 1 : 0,
                        focusedRail: _railFocus,
                        onRailFocus: (i) => setState(() => _railFocus = i),
                        vm: vm,
                        safePad: safePad,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
                  ],

                  // Videos
                  if (videos.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _TVContentRail(
                        title: 'VIDEO ARCHIVE',
                        subTitle: 'PATH // ROOT/VIDEOS',
                        items: videos,
                        railIndex: continueWatching.isNotEmpty ? 1 : 0,
                        focusedRail: _railFocus,
                        onRailFocus: (i) => setState(() => _railFocus = i),
                        vm: vm,
                        safePad: safePad,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
                  ],

                  // Audio
                  if (audio.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _TVContentRail(
                        title: 'AUDIO MATRIX',
                        subTitle: 'PATH // ROOT/AUDIO',
                        items: audio,
                        railIndex: _calcRailIndex(continueWatching, videos, 2),
                        focusedRail: _railFocus,
                        onRailFocus: (i) => setState(() => _railFocus = i),
                        vm: vm,
                        safePad: safePad,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
                  ],

                  // Images
                  if (images.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _TVContentRail(
                        title: 'PHOTO DB',
                        subTitle: 'PATH // ROOT/IMAGES',
                        items: images,
                        railIndex: _calcRailIndex(continueWatching, videos, 3),
                        focusedRail: _railFocus,
                        onRailFocus: (i) => setState(() => _railFocus = i),
                        vm: vm,
                        safePad: safePad,
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    ));
  }

  int _calcRailIndex(List continueWatching, List videos, int base) {
    int idx = context.read<ClientViewModel>().stations.isNotEmpty ? 1 : 0;
    if (continueWatching.isNotEmpty) idx++;
    if (videos.isNotEmpty) idx++;
    return idx + (base - 2);
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

// ─────────────────────────────────────────────────────────────────────────────
// TV HERO SLIDER SECTION (Industrial Brutalist Style)
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
  bool _hasFocus = false;

  DateTime _lastInteraction = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!_hasFocus && DateTime.now().difference(_lastInteraction).inSeconds > 10) {
          if (_pageCtrl.hasClients) {
            int next = _currentPage + 1;
            if (next >= widget.items.length) next = 0;
            _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 0), curve: Curves.linear);
          }
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

  void _recordInteraction() {
    _lastInteraction = DateTime.now();
  }

  void _play(BuildContext context, MediaItem item) {
    final idx = widget.allItems.indexOf(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TVPlayerScreen(items: widget.allItems, startIndex: idx >= 0 ? idx : 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final titleFs = (size.width * 0.025).clamp(24.0, 56.0);
    final btnWidth = (size.width * 0.1).clamp(140.0, 200.0);

    return Focus(
      onFocusChange: (v) => setState(() => _hasFocus = v),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final thumbUrl = widget.vm.thumbnailUrl(item.id);

              return Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: kWebBorder)),
                ),
                child: Column(
                  children: [
                    // Main Image Area
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: kWebSurface2,
                        child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: item.isAudio ? LucideIcons.music : LucideIcons.video),
                      ),
                    ),
                    // Brutalist Bottom Bar
                    Container(
                      height: (size.height * 0.18).clamp(90.0, 150.0),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: kWebSurface,
                        border: Border(top: BorderSide(color: kWebBorder)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      color: kWebWhite,
                                      child: Text(
                                        'FEATURED',
                                        style: GoogleFonts.dmMono(color: kWebBlack, fontSize: (size.width * 0.008).clamp(9.0, 12.0), fontWeight: FontWeight.bold, letterSpacing: 2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'STATUS // ${item.type.toUpperCase()}',
                                      style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: (size.width * 0.008).clamp(9.0, 12.0), letterSpacing: 2),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.title.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: titleFs, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          _TVHeroButton(icon: LucideIcons.play, label: 'PLAY', width: btnWidth, isPrimary: true, onFocus: _recordInteraction, onTap: () => _play(context, item)),
                          const SizedBox(width: 12),
                          _TVHeroButton(icon: LucideIcons.info, label: 'INFO', width: btnWidth, isPrimary: false, onFocus: _recordInteraction, onTap: () {}),
                        ],
                      ),
                    ),
                  ],
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
                    child: Container(height: 4, margin: const EdgeInsets.only(right: 1), color: _currentPage == index ? kWebWhite : Colors.black54),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TVHeroButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final double width;
  final VoidCallback onTap;
  final VoidCallback onFocus;

  const _TVHeroButton({required this.icon, required this.label, required this.isPrimary, required this.width, required this.onTap, required this.onFocus});

  @override
  State<_TVHeroButton> createState() => _TVHeroButtonState();
}

class _TVHeroButtonState extends State<_TVHeroButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
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
          if (v) {
            widget.onFocus();
            Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 250));
          }
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isFocused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.width,
              padding: EdgeInsets.symmetric(vertical: (widget.width * 0.08).clamp(12.0, 20.0)),
              decoration: BoxDecoration(
                color: _isFocused ? kWebWhite : (widget.isPrimary ? kWebWhite.withValues(alpha: 0.1) : kWebSurface2),
                border: Border.all(color: _isFocused ? kWebWhite : kWebBorder, width: _isFocused ? 4 : 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: _isFocused ? kWebBlack : kWebWhite, size: (widget.width * 0.1).clamp(18.0, 28.0)),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: GoogleFonts.dmMono(color: _isFocused ? kWebBlack : kWebWhite, fontWeight: FontWeight.bold, fontSize: (widget.width * 0.08).clamp(14.0, 22.0), letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV CONTENT RAIL (Brutalist Filmstrip)
// ─────────────────────────────────────────────────────────────────────────────

class _TVContentRail extends StatefulWidget {
  final String title;
  final String subTitle;
  final List<MediaItem> items;
  final bool showProgress;
  final int railIndex;
  final int focusedRail;
  final void Function(int) onRailFocus;
  final double safePad;
  final ClientViewModel vm;

  const _TVContentRail({
    required this.title,
    required this.subTitle,
    required this.items,
    required this.railIndex,
    required this.focusedRail,
    required this.onRailFocus,
    required this.safePad,
    required this.vm,
    this.showProgress = false,
  });

  @override
  State<_TVContentRail> createState() => _TVContentRailState();
}

class _TVContentRailState extends State<_TVContentRail> {
  final ScrollController _scrollCtrl = ScrollController();
  int _focusedCard = -1;

  void _onCardFocus(int index, double cardW, double sidePadding) {
    setState(() => _focusedCard = index);
    widget.onRailFocus(widget.railIndex);

    Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 250));

    // Calculate offset considering zero margin between cards in the brutalist strip
    final offset = index * cardW - sidePadding;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent), duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    }
  }

  void _play(MediaItem item) {
    final idx = widget.items.indexOf(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TVPlayerScreen(items: widget.items, startIndex: idx >= 0 ? idx : 0),
      ),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sidePadding = (size.width * 0.015).clamp(16.0, 48.0);

    // Dynamic Rail Dimensions
    final double cardW = (size.width * 0.15).clamp(200.0, 380.0);
    final double cardH = cardW;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title.toUpperCase(),
                style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: (size.width * 0.015).clamp(18.0, 28.0), fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subTitle.toUpperCase(),
                style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: (size.width * 0.008).clamp(9.0, 12.0), letterSpacing: 2),
              ),
            ],
          ),
        ),
        Container(
          height: cardH,
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)),
            color: kWebSurface,
          ),
          child: ListView.builder(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: widget.items.length,
            clipBehavior: Clip.none, // Allow cards to scale outside bounds on TV
            itemBuilder: (_, i) => _TVRailCard(
              item: widget.items[i],
              width: cardW,
              height: cardH,
              showProgress: widget.showProgress,
              isFocused: _focusedCard == i && widget.focusedRail == widget.railIndex,
              vm: widget.vm,
              onFocus: (cardCtx) => _onCardFocus(i, cardW, sidePadding),
              onTap: () => _play(widget.items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _TVRailCard extends StatefulWidget {
  final MediaItem item;
  final double width;
  final double height;
  final bool showProgress;
  final bool isFocused;
  final ClientViewModel vm;
  final void Function(BuildContext context) onFocus;
  final VoidCallback onTap;

  const _TVRailCard({required this.item, required this.width, required this.height, required this.showProgress, required this.isFocused, required this.vm, required this.onFocus, required this.onTap});

  @override
  State<_TVRailCard> createState() => _TVRailCardState();
}

class _TVRailCardState extends State<_TVRailCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_TVRailCard old) {
    super.didUpdateWidget(old);
    widget.isFocused ? _scaleCtrl.forward() : _scaleCtrl.reverse();
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
        onFocusChange: (focused) {
          if (focused) widget.onFocus(context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.isFocused ? kWebWhite : kWebSurface2,
                border: Border(
                  right: BorderSide(color: kWebBorder),
                  top: widget.isFocused ? BorderSide(color: kWebWhite, width: 4) : BorderSide.none,
                  bottom: widget.isFocused ? BorderSide(color: kWebWhite, width: 4) : BorderSide.none,
                  left: widget.isFocused ? BorderSide(color: kWebWhite, width: 4) : BorderSide.none,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Poster (78%)
                  Expanded(
                    flex: 78,
                    child: Container(
                      color: kWebBlack,
                      child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.isAudio ? LucideIcons.music : LucideIcons.video),
                    ),
                  ),

                  // Progress Bar
                  if (widget.showProgress && widget.item.isInProgress)
                    Container(
                      height: 2,
                      alignment: Alignment.centerLeft,
                      color: kWebBorder,
                      child: FractionallySizedBox(
                        widthFactor: widget.item.watchProgress,
                        child: Container(color: widget.isFocused ? kWebBlack : kWebWhite),
                      ),
                    ),

                  // Info (22%)
                  Expanded(
                    flex: 22,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: kWebBorder)),
                      ),
                      child: Text(
                        widget.item.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmMono(
                          color: widget.isFocused ? kWebBlack : kWebText,
                          fontSize: (widget.width * 0.05).clamp(10.0, 14.0),
                          fontWeight: widget.isFocused ? FontWeight.bold : FontWeight.normal,
                          letterSpacing: 1,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 80),
      decoration: BoxDecoration(
        border: Border.all(color: kWebBorder, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.wifiHigh, size: 64, color: kWebTextMuted),
          const SizedBox(height: DS.s24),
          Text(
            'SIGNAL ERROR // DISCONNECTED',
            style: GoogleFonts.barlowCondensed(color: kWebTextMuted, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV STATION RAIL
// ─────────────────────────────────────────────────────────────────────────────

class _TVStationRail extends StatefulWidget {
  final List<Map<String, dynamic>> stations;
  final int railIndex;
  final int focusedRail;
  final void Function(int) onRailFocus;
  final double safePad;
  final ClientViewModel vm;

  const _TVStationRail({required this.stations, required this.railIndex, required this.focusedRail, required this.onRailFocus, required this.safePad, required this.vm});

  @override
  State<_TVStationRail> createState() => _TVStationRailState();
}

class _TVStationRailState extends State<_TVStationRail> {
  final ScrollController _scrollCtrl = ScrollController();
  int _focusedCard = -1;

  void _onCardFocus(int index, double cardW, double sidePadding) {
    setState(() => _focusedCard = index);
    widget.onRailFocus(widget.railIndex);
    Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 250));
    final offset = index * cardW - sidePadding;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent), duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sidePadding = (size.width * 0.015).clamp(16.0, 48.0);
    final double cardW = (size.width * 0.15).clamp(200.0, 380.0);
    final double cardH = cardW;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NETWORK BROADCASTS',
                style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: (size.width * 0.015).clamp(18.0, 28.0), fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 2),
              Text(
                'PATH // ROOT/LIVE',
                style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: (size.width * 0.008).clamp(9.0, 12.0), letterSpacing: 2),
              ),
            ],
          ),
        ),
        Container(
          height: cardH + 50,
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: kWebBorder)),
            color: kWebSurface,
          ),
          child: ListView.builder(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: widget.stations.length,
            clipBehavior: Clip.none,
            itemBuilder: (_, i) => _TVStationCard(
              station: widget.stations[i],
              width: cardW,
              height: cardH,
              isFocused: _focusedCard == i && widget.focusedRail == widget.railIndex,
              vm: widget.vm,
              onFocus: () => _onCardFocus(i, cardW, sidePadding),
            ),
          ),
        ),
      ],
    );
  }
}

class _TVStationCard extends StatefulWidget {
  final Map<String, dynamic> station;
  final double width;
  final double height;
  final bool isFocused;
  final ClientViewModel vm;
  final VoidCallback onFocus;

  const _TVStationCard({required this.station, required this.width, required this.height, required this.isFocused, required this.vm, required this.onFocus});

  @override
  State<_TVStationCard> createState() => _TVStationCardState();
}

class _TVStationCardState extends State<_TVStationCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_TVStationCard old) {
    super.didUpdateWidget(old);
    widget.isFocused ? _scaleCtrl.forward() : _scaleCtrl.reverse();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

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
          builder: (_) => TVPlayerScreen(
            items: items,
            startIndex: startIndex,
            isPathBased: false,
            startOffset: Duration(milliseconds: offsetMs),
            autoPlay: !isPaused,
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

    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _tuneIn();
            return null;
          },
        ),
      },
      child: Focus(
        onFocusChange: (f) {
          if (f) widget.onFocus();
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, _tuneIn),
        child: GestureDetector(
          onTap: _tuneIn,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.isFocused ? kWebWhite : kWebSurface2,
                border: Border(
                  right: BorderSide(color: kWebBorder),
                  top: widget.isFocused ? BorderSide(color: kWebWhite, width: 4) : BorderSide.none,
                  bottom: widget.isFocused ? BorderSide(color: kWebWhite, width: 4) : BorderSide.none,
                  left: widget.isFocused ? BorderSide(color: kWebWhite, width: 4) : BorderSide.none,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.barlowCondensed(color: widget.isFocused ? kWebBlack : kWebWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                          maxLines: 1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: widget.isFocused ? kWebBlack : kWebWhite)),
                        child: Text(
                          'LIVE',
                          style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isFocused ? kWebBlack : kWebWhite),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STATUS // NOW PLAYING', style: GoogleFonts.dmMono(fontSize: 10, color: widget.isFocused ? kWebBlack.withValues(alpha: 0.5) : kWebTextMuted, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(
                        itemTitle,
                        style: GoogleFonts.dmMono(fontSize: 12, color: widget.isFocused ? kWebBlack : kWebText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV SEARCH SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _TVSearchScreen extends StatefulWidget {
  final List<MediaItem> allMedia;
  const _TVSearchScreen({required this.allMedia});

  @override
  State<_TVSearchScreen> createState() => _TVSearchScreenState();
}

class _TVSearchScreenState extends State<_TVSearchScreen> {
  String _query = '';
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  int _focusedIndex = -1;

  List<MediaItem> get _results {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return widget.allMedia.where((m) => m.title.toLowerCase().contains(q) || m.folder.toLowerCase().contains(q)).take(50).toList();
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

  void _play(MediaItem item) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TVPlayerScreen(items: [item], startIndex: 0)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ClientViewModel>();
    final results = _results;
    final size = MediaQuery.sizeOf(context);
    const double sidePadding = 24.0;

    return Scaffold(
      backgroundColor: kWebBlack,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search input (Top bar)
            Container(
              height: (size.height * 0.1).clamp(70.0, 100.0),
              decoration: BoxDecoration(
                color: kWebSurface,
                border: Border(bottom: BorderSide(color: kWebBorder)),
              ),
              child: Row(
                children: [
                  SizedBox(width: sidePadding),
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
                      onFocusChange: (f) {
                        if (f) Scrollable.ensureVisible(context, alignment: 0.0, duration: const Duration(milliseconds: 250));
                      },
                      onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => Navigator.pop(context)),
                      child: IconButton(
                        icon: Icon(LucideIcons.arrowLeft, color: kWebText, size: (size.width * 0.02).clamp(24.0, 32.0)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('CMD>', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: (size.width * 0.015).clamp(16.0, 24.0))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: GoogleFonts.dmMono(color: kWebWhite, fontSize: (size.width * 0.015).clamp(16.0, 24.0), letterSpacing: 2),
                      cursorColor: kWebWhite,
                      decoration: InputDecoration(
                        hintText: 'SEARCH QUERY...',
                        hintStyle: TextStyle(color: kWebTextMuted),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) {
                        setState(() {
                          _query = v;
                          _focusedIndex = -1;
                        });
                      },
                    ),
                  ),
                  if (_query.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Text('${results.length} SIGNALS FOUND', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: (size.width * 0.01).clamp(12.0, 16.0), letterSpacing: 2)),
                    SizedBox(width: sidePadding),
                  ],
                ],
              ),
            ),

            // Results grid
            Expanded(
              child: _query.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
                        decoration: BoxDecoration(
                          border: Border.all(color: kWebBorder, style: BorderStyle.solid),
                        ),
                        child: Text('AWAITING SIGNAL // CMD READY', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 16, letterSpacing: 4)),
                      ),
                    )
                  : results.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 80),
                        decoration: BoxDecoration(
                          border: Border.all(color: kWebBorder, style: BorderStyle.solid),
                        ),
                        child: Text('0 SIGNALS FOUND FOR "${_query.toUpperCase()}"', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 16, letterSpacing: 4)),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(color: kWebBorder),
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: sidePadding, vertical: sidePadding),
                        // 5 columns for TV layout
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, childAspectRatio: 1.0, crossAxisSpacing: 1, mainAxisSpacing: 1),
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final item = results[i];
                          return _TVSearchGridCard(
                            item: item,
                            isFocused: _focusedIndex == i,
                            vm: vm,
                            onFocus: (cardCtx) {
                              setState(() => _focusedIndex = i);
                              Scrollable.ensureVisible(cardCtx, alignment: 0.5, duration: const Duration(milliseconds: 250));
                            },
                            onTap: () => _play(item),
                          );
                        },
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
// TV SEARCH GRID CARD
// ─────────────────────────────────────────────────────────────────────────────
class _TVSearchGridCard extends StatefulWidget {
  final MediaItem item;
  final bool isFocused;
  final ClientViewModel vm;
  final void Function(BuildContext context) onFocus;
  final VoidCallback onTap;

  const _TVSearchGridCard({required this.item, required this.isFocused, required this.vm, required this.onFocus, required this.onTap});

  @override
  State<_TVSearchGridCard> createState() => _TVSearchGridCardState();
}

class _TVSearchGridCardState extends State<_TVSearchGridCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_TVSearchGridCard old) {
    super.didUpdateWidget(old);
    widget.isFocused ? _scaleCtrl.forward() : _scaleCtrl.reverse();
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
        onFocusChange: (focused) {
          if (focused) widget.onFocus(context);
        },
        onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
        child: GestureDetector(
          onTap: widget.onTap,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              decoration: BoxDecoration(
                color: widget.isFocused ? kWebWhite : kWebSurface2,
                border: Border.all(color: widget.isFocused ? kWebWhite : kWebBorder, width: widget.isFocused ? 4 : 0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 78,
                    child: Container(
                      color: kWebBlack,
                      child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.isAudio ? LucideIcons.music : LucideIcons.video),
                    ),
                  ),
                  Expanded(
                    flex: 22,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: kWebBorder)),
                      ),
                      child: Text(
                        widget.item.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmMono(color: widget.isFocused ? kWebBlack : kWebText, fontSize: 12, fontWeight: widget.isFocused ? FontWeight.bold : FontWeight.normal, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
