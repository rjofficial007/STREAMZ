// presentation/tv/tv_home_screen.dart
// ============================================================================
// STREAMZ — TV Home Screen (Netflix-style Hero Slider & Content Rails)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/models/media_item.dart';
import '../client/client_viewmodel.dart';
import '../player/player_screen.dart';

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
    final continueWatching = vm.continueWatching;
    final videos = vm.videos;
    final audio = vm.audio;
    final images = vm.images;

    // Dynamic TV Scaling constraints (Adapts to 720p, 1080p, 4K)
    final size = MediaQuery.sizeOf(context);
    final hPad = (size.width * 0.04).clamp(32.0, 80.0);
    final vSpacing = (size.height * 0.04).clamp(24.0, 48.0);

    // Grab up to 5 items to feature in the Hero Slider
    final featuredItems = [...continueWatching, ...videos].take(5).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: DS.bg,
        extendBodyBehindAppBar: true,
        body: allMedia.isEmpty
            ? const Center(child: _EmptyState())
            : CustomScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(), // Prevent bounce on TVs
                slivers: [
                  // Persistent TV Top Bar
                  SliverAppBar(
                    backgroundColor: _isScrolled ? DS.bg.withValues(alpha: 0.95) : Colors.transparent,
                    floating: true,
                    elevation: 0,
                    pinned: true,
                    toolbarHeight: (size.height * 0.1).clamp(60.0, 100.0),
                    leadingWidth: 80,
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 24),
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
                            icon: Icon(LucideIcons.arrowLeft, color: DS.textPrimary, size: (size.width * 0.02).clamp(24.0, 32.0)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      'STREAMZ',
                      style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: (size.width * 0.015).clamp(16.0, 24.0), letterSpacing: 6, color: DS.accent, fontWeight: FontWeight.bold),
                    ),
                    centerTitle: false,
                    actions: [
                      Center(
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF30D158),
                                boxShadow: [BoxShadow(color: Color(0xFF30D158), blurRadius: 6)],
                              ),
                            ),
                            const SizedBox(width: DS.s12),
                            Text(vm.targetIp, style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: (size.width * 0.01).clamp(10.0, 14.0))),
                            const SizedBox(width: DS.s32),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 24),
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
                              icon: Icon(LucideIcons.search, color: DS.textPrimary, size: (size.width * 0.02).clamp(24.0, 32.0)),
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
                        child: Container(color: DS.borderDefault, height: 1),
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

                  // Continue Watching
                  if (continueWatching.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _TVContentRail(
                        title: 'CONTINUE WATCHING',
                        items: continueWatching,
                        showProgress: true,
                        railIndex: 0,
                        focusedRail: _railFocus,
                        onRailFocus: (i) => setState(() => _railFocus = i),
                        vm: vm,
                        hPad: hPad,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
                  ],

                  // Videos
                  if (videos.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _TVContentRail(
                        title: 'VIDEOS',
                        items: videos,
                        railIndex: continueWatching.isNotEmpty ? 1 : 0,
                        focusedRail: _railFocus,
                        onRailFocus: (i) => setState(() => _railFocus = i),
                        vm: vm,
                        hPad: hPad,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
                  ],

                  // Audio
                  if (audio.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _TVContentRail(
                        title: 'AUDIO',
                        items: audio,
                        isSquare: true,
                        railIndex: _calcRailIndex(continueWatching, videos, 2),
                        focusedRail: _railFocus,
                        onRailFocus: (i) => setState(() => _railFocus = i),
                        vm: vm,
                        hPad: hPad,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: vSpacing)),
                  ],

                  // Images
                  if (images.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _TVContentRail(
                        title: 'PHOTOS',
                        items: images,
                        railIndex: _calcRailIndex(continueWatching, videos, 3),
                        focusedRail: _railFocus,
                        onRailFocus: (i) => setState(() => _railFocus = i),
                        vm: vm,
                        hPad: hPad,
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }

  int _calcRailIndex(List continueWatching, List videos, int base) {
    int idx = 0;
    if (continueWatching.isNotEmpty) idx++;
    if (videos.isNotEmpty) idx++;
    return idx + (base - 2);
  }

  void _openSearch(BuildContext context, List<MediaItem> allMedia) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<ClientViewModel>(),
          child: _TVSearchScreen(allMedia: allMedia),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV HERO SLIDER SECTION
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

  // Anti-Focus Trap: Tracks when the user last moved their D-Pad into the Hero
  DateTime _lastInteraction = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        // Only auto-slide if the user hasn't interacted with the Hero in the last 10 seconds.
        // This prevents the UI from stealing focus and destroying the D-Pad cursor.
        if (DateTime.now().difference(_lastInteraction).inSeconds > 10) {
          if (_pageCtrl.hasClients) {
            int next = _currentPage + 1;
            if (next >= widget.items.length) next = 0;
            _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
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
        builder: (_) => PlayerScreen(items: widget.allItems, startIndex: idx >= 0 ? idx : 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final titleFs = (size.width * 0.035).clamp(32.0, 72.0);
    final btnWidth = (size.width * 0.12).clamp(160.0, 240.0);

    return Stack(
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
                      colors: [Colors.transparent, DS.bg.withValues(alpha: 0.2), DS.bg.withValues(alpha: 0.8), DS.bg],
                      stops: const [0.0, 0.4, 0.8, 1.0],
                    ),
                  ),
                ),

                // Content Details & Actions
                Positioned(
                  bottom: (size.height * 0.05).clamp(24.0, 60.0),
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
                            style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.accent, letterSpacing: 4, fontWeight: FontWeight.bold, fontSize: (size.width * 0.01).clamp(10.0, 16.0)),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: DS.textMuted, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.type.toUpperCase(),
                            style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.textMuted, fontSize: (size.width * 0.01).clamp(10.0, 16.0)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: size.width * 0.1),
                        child: Text(
                          item.title.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: AppTheme.theme.textTheme.displayMedium?.copyWith(fontSize: titleFs, height: 1.1),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Actions (Play / Info)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TVHeroButton(icon: LucideIcons.play, label: 'PLAY', width: btnWidth, isPrimary: true, onFocus: _recordInteraction, onTap: () => _play(context, item)),
                          const SizedBox(width: 24),
                          _TVHeroButton(
                            icon: LucideIcons.info,
                            label: 'INFO',
                            width: btnWidth,
                            isPrimary: false,
                            onFocus: _recordInteraction,
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
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.items.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  height: 6,
                  width: _currentPage == index ? 24 : 6,
                  decoration: BoxDecoration(color: _currentPage == index ? DS.accent : Colors.white30, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
          ),
      ],
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
            widget.onFocus(); // Inform the parent to stop auto-sliding
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
                color: widget.isPrimary ? (_isFocused ? DS.accent : Colors.white) : (_isFocused ? Colors.white : DS.surface2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _isFocused ? Colors.white : Colors.transparent, width: _isFocused ? 3 : 0),
                boxShadow: _isFocused ? [BoxShadow(color: (widget.isPrimary ? DS.accent : Colors.white).withValues(alpha: 0.4), blurRadius: 20)] : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: widget.isPrimary ? Colors.black : (_isFocused ? Colors.black : Colors.white), size: (widget.width * 0.1).clamp(18.0, 28.0)),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: AppTheme.theme.textTheme.labelMedium?.copyWith(
                      color: widget.isPrimary ? Colors.black : (_isFocused ? Colors.black : Colors.white),
                      fontWeight: FontWeight.bold,
                      fontSize: (widget.width * 0.08).clamp(14.0, 22.0),
                      letterSpacing: 2,
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
// TV CONTENT RAIL
// ─────────────────────────────────────────────────────────────────────────────

class _TVContentRail extends StatefulWidget {
  final String title;
  final List<MediaItem> items;
  final bool showProgress;
  final bool isSquare;
  final int railIndex;
  final int focusedRail;
  final void Function(int) onRailFocus;
  final double hPad;
  final ClientViewModel vm;

  const _TVContentRail({
    required this.title,
    required this.items,
    required this.railIndex,
    required this.focusedRail,
    required this.onRailFocus,
    required this.hPad,
    required this.vm,
    this.showProgress = false,
    this.isSquare = false,
  });

  @override
  State<_TVContentRail> createState() => _TVContentRailState();
}

class _TVContentRailState extends State<_TVContentRail> {
  final ScrollController _scrollCtrl = ScrollController();
  int _focusedCard = -1;

  void _onCardFocus(int index, double cardW) {
    setState(() => _focusedCard = index);
    widget.onRailFocus(widget.railIndex);

    Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 250));

    final offset = index * (cardW + DS.s16) - widget.hPad;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent), duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    }
  }

  void _play(MediaItem item) {
    final idx = widget.items.indexOf(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(items: widget.items, startIndex: idx >= 0 ? idx : 0),
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

    // Dynamic Rail Dimensions
    final double cardW = widget.isSquare ? (size.width * 0.12).clamp(160.0, 320.0) : (size.width * 0.16).clamp(240.0, 480.0);
    final double cardH = widget.isSquare ? cardW : cardW * (9 / 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(widget.hPad, 0, widget.hPad, 12),
          child: Text(
            widget.title,
            style: AppTheme.theme.textTheme.labelMedium?.copyWith(letterSpacing: 2, fontSize: (size.width * 0.012).clamp(14.0, 24.0), fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: cardH + 20, // Pad height to allow for hover scale
          child: ListView.builder(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: widget.hPad),
            itemCount: widget.items.length,
            clipBehavior: Clip.none, // Allow cards to scale outside bounds
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _TVRailCard(
                item: widget.items[i],
                width: cardW,
                height: cardH,
                showProgress: widget.showProgress,
                isFocused: _focusedCard == i && widget.focusedRail == widget.railIndex,
                vm: widget.vm,
                onFocus: (cardCtx) => _onCardFocus(i, cardW),
                onTap: () => _play(widget.items[i]),
              ),
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
    _scale = Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: DS.surface1,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: widget.isFocused ? Colors.white : Colors.transparent, width: widget.isFocused ? 4 : 0),
                boxShadow: widget.isFocused ? [BoxShadow(color: DS.accent.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 4)] : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: widget.isFocused ? 1.0 : 0.7,
                      child: NetworkImageFade(url: thumbUrl, fit: BoxFit.cover, fallbackIcon: widget.item.isAudio ? LucideIcons.music : LucideIcons.video),
                    ),

                    // Gradient overlay
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC000000)], stops: [0.5, 1.0]),
                      ),
                    ),

                    // Title
                    Positioned(
                      bottom: DS.s12,
                      left: DS.s12,
                      right: DS.s12,
                      child: Text(
                        widget.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.theme.textTheme.labelMedium?.copyWith(
                          fontSize: (widget.width * 0.06).clamp(11.0, 18.0),
                          height: 1.2,
                          fontWeight: FontWeight.bold,
                          color: widget.isFocused ? Colors.white : DS.textSecondary,
                        ),
                      ),
                    ),

                    // Watch progress bar
                    if (widget.showProgress && widget.item.isInProgress)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(value: widget.item.watchProgress, backgroundColor: Colors.transparent, valueColor: const AlwaysStoppedAnimation(Colors.red), minHeight: 4),
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
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(LucideIcons.wifiHigh, size: 64, color: DS.textMuted),
        const SizedBox(height: DS.s24),
        Text('NO SIGNAL', style: AppTheme.theme.textTheme.displayMedium?.copyWith(fontSize: 48, color: DS.textMuted)),
        const SizedBox(height: DS.s12),
        Text('CONNECT TO A SERVER TO BEGIN STREAMING', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 4)),
      ],
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(items: [item], startIndex: 0)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ClientViewModel>();
    final results = _results;
    final size = MediaQuery.sizeOf(context);
    final hPad = (size.width * 0.04).clamp(32.0, 80.0);
    final cardW = (size.width * 0.16).clamp(240.0, 480.0);

    return Scaffold(
      backgroundColor: DS.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search input
            Container(
              padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 16),
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
                      onFocusChange: (f) {
                        if (f) Scrollable.ensureVisible(context, alignment: 0.0, duration: const Duration(milliseconds: 250));
                      },
                      onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => Navigator.pop(context)),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: DS.borderDefault),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(LucideIcons.arrowLeft, color: DS.textPrimary, size: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: 24, letterSpacing: 2),
                      decoration: const InputDecoration(
                        hintText: 'SEARCH LIBRARY...',
                        hintStyle: TextStyle(color: DS.textMuted),
                        border: InputBorder.none,
                        prefixIcon: Icon(LucideIcons.search, color: DS.textMuted, size: 24),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _query = v;
                          _focusedIndex = -1;
                        });
                      },
                    ),
                  ),
                  if (_query.isNotEmpty) ...[const SizedBox(width: 16), Text('${results.length} RESULTS', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 14))],
                ],
              ),
            ),

            // Results grid
            Expanded(
              child: _query.isEmpty
                  ? Center(child: Text('START TYPING TO SEARCH', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 4)))
                  : results.isEmpty
                  ? Center(child: Text('NO RESULTS FOR "${_query.toUpperCase()}"', style: AppTheme.theme.textTheme.labelSmall?.copyWith(letterSpacing: 3)))
                  : GridView.builder(
                      padding: EdgeInsets.all(hPad),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: cardW, childAspectRatio: 16 / 9, crossAxisSpacing: 16, mainAxisSpacing: 16),
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final item = results[i];
                        return _TVRailCard(
                          item: item,
                          width: cardW,
                          height: cardW * (9 / 16),
                          showProgress: true,
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
          ],
        ),
      ),
    );
  }
}
