// presentation/tv/tv_player_screen.dart
// ============================================================================
// STREAMZ — TV Dedicated Media Player (VLC-Inspired Brutalist Edition)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/player/player_viewmodel.dart';
import 'package:streamz/presentation/player/widgets/low_fi_indicator.dart';
import 'package:streamz/presentation/player/widgets/player_sync_tile.dart';
import 'package:streamz/presentation/player/widgets/player_track_tile.dart';
import 'package:streamz/presentation/shared/atmospheric_background.dart';
import 'package:streamz/widget/glitch_effect.dart';


class TVPlayerScreen extends StatefulWidget {

  const TVPlayerScreen({
    super.key,
    required this.items,
    required this.startIndex,
    this.isPathBased = false,
    this.startOffset,
    this.autoPlay = true,
  });
  final List<MediaItem> items;
  final int startIndex;
  final bool isPathBased;
  final Duration? startOffset;
  final bool autoPlay;

  @override
  State<TVPlayerScreen> createState() => _TVPlayerScreenState();
}

class _TVPlayerScreenState extends State<TVPlayerScreen> {
  late final PlayerViewModel _vm;
  final FocusScopeNode _osdFocusScope = FocusScopeNode();
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _sidebarFirstItemFocusNode = FocusNode();
  final GlobalKey _repaintKey = GlobalKey();

  bool _wasOSDVisible = true;
  bool _showSidebar = false;

  @override
  void initState() {
    super.initState();
    _vm = PlayerViewModel();
    _vm.load(
      items: widget.items,
      startIndex: widget.startIndex,
      isPathBased: widget.isPathBased,
      startOffset: widget.startOffset,
      autoPlay: widget.autoPlay,
    ).then((_) {
      if (mounted) {
        _playPauseFocusNode.requestFocus();
      }
    });
    _vm.snapshotCallback = _captureSnapshot;
    _wasOSDVisible = _vm.showOSD;
    _vm.addListener(_onVMChange);
  }

  Future<String?> _captureSnapshot() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 0.15); // Low res for speed
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return base64Encode(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  void _onVMChange() {
    if (mounted) {
      if (_vm.isStopped) {
        context.pop();
        return;
      }
      if (_vm.showOSD && !_wasOSDVisible) {
        _playPauseFocusNode.requestFocus();
      }
      _wasOSDVisible = _vm.showOSD;
      if (!_vm.showOSD && _showSidebar) {
        _showSidebar = false;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _vm..removeListener(_onVMChange)
    ..dispose();
    _osdFocusScope.dispose();
    _playPauseFocusNode.dispose();
    _sidebarFirstItemFocusNode.dispose();
    super.dispose();
  }

  // ── Key Handling (VLC Style) ──────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final item = _vm.current;

    // 1. GLOBAL NAVIGATION & EXIT (Top priority)
    if (_isExitKey(key)) {
      return _handleExitRequest();
    }

    // 2. VOLUME CONTROL
    if (key == LogicalKeyboardKey.audioVolumeUp) {
      _vm.adjustVolume(5);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.audioVolumeDown) {
      _vm.adjustVolume(-5);
      return KeyEventResult.handled;
    }

    // 3. DEDICATED MEDIA KEYS (Hardware buttons)
    final mediaResult = _handleDedicatedMediaKeys(key, item);
    if (mediaResult == KeyEventResult.handled) return KeyEventResult.handled;

    // 4. INFO & SIDEBAR
    if (key == LogicalKeyboardKey.info || key == LogicalKeyboardKey.guide) {
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu) {
      _toggleSidebar(true);
      return KeyEventResult.handled;
    }

    // 5. OSD-HIDDEN SPECIFIC KEYS (DPad interactions when OSD is gone)
    if (!_vm.showOSD) {
      return _handleHiddenOSDKeys(key, item);
    }

    // 6. OSD-VISIBLE KEYS (Delegate to Focus System)
    _vm.wakeOSD();
    return KeyEventResult.ignored;
  }

  bool _isExitKey(LogicalKeyboardKey key) => key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.exit;

  KeyEventResult _handleExitRequest() {
    if (_showSidebar) {
      _toggleSidebar(false);
      return KeyEventResult.handled;
    }
    if (_vm.showOSD) {
      _vm.hideOSD();
      return KeyEventResult.handled;
    }
    context.pop();
    return KeyEventResult.handled;
  }

  KeyEventResult _handleDedicatedMediaKeys(LogicalKeyboardKey key, MediaItem? item) {
    if (key == LogicalKeyboardKey.mediaPlay || key == LogicalKeyboardKey.space) {
      if (!_vm.player.state.playing) {
        _vm.player.play();
      } else if (key == LogicalKeyboardKey.space) {
        _vm.player.pause();
      }
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      _vm.player.pause();
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      _vm.player.playOrPause();
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaStop) {
      context.pop();
      return KeyEventResult.handled;
    }
    if (item?.isVideo == true && item?.isBroadcast != true) {
      if (key == LogicalKeyboardKey.mediaFastForward) {
        _vm.seekRelative(const Duration(seconds: 10));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaRewind) {
        _vm.seekRelative(const Duration(seconds: -10));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleHiddenOSDKeys(LogicalKeyboardKey key, MediaItem? item) {
    _vm.wakeOSD();

    // Channel Switching
    if (key == LogicalKeyboardKey.channelUp || key == LogicalKeyboardKey.pageUp) {
      _cycleStation(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.channelDown || key == LogicalKeyboardKey.pageDown) {
      _cycleStation(-1);
      return KeyEventResult.handled;
    }

    // Seeking (D-pad)
    if (item?.isVideo == true && item?.isBroadcast != true) {
      if (key == LogicalKeyboardKey.arrowRight) {
        _vm.seekRelative(const Duration(seconds: 10));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        _vm.seekRelative(const Duration(seconds: -10));
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.handled;
  }

  void _toggleSidebar(bool show) {
    setState(() => _showSidebar = show);
    if (show) {
      _sidebarFirstItemFocusNode.requestFocus();
      _vm.wakeOSD();
    } else {
      _playPauseFocusNode.requestFocus();
    }
  }

  // ── Station Switching ─────────────────────────────────────────────────────

  void _cycleStation(int delta) {
    final clientVM = context.read<ClientViewModel>();
    final stations = clientVM.stations;
    if (stations.isEmpty) return;

    final currentStationId = _vm.current?.folder;
    var idx = stations.indexWhere((s) => s.id == currentStationId);
    
    if (idx == -1) {
      idx = 0;
    } else {
      idx = (idx + delta) % stations.length;
    }
    _switchStation(stations[idx]);
  }

  Future<void> _switchStation(BroadcastStation station) async {
    final clientVM = context.read<ClientViewModel>();
    final res = await clientVM.joinStation(station.id);
    if (res != null && mounted) {
      unawaited(_vm.load(
        items: res.playlist,
        startIndex: res.itemIndex,
        isPathBased: false,
        startOffset: res.position,
        autoPlay: !res.isPaused,
      ));
    }
  }

  void _showStationModal() {
    final clientVM = context.read<ClientViewModel>();
    final stations = clientVM.stations;
    final tokens = context.tokens;

    showGeneralDialog(
      context: context,
      barrierColor: tokens.background.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: FocusScope(
          autofocus: true,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 540,
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                    child: Text('LIVE BROADCAST STATIONS', style: AppTextStyles.barlowBold(28, spacing: 2, color: tokens.textPrimary)),
                  ),
                  if (stations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('NO ACTIVE BROADCASTS FOUND', style: AppTextStyles.mono(16, spacing: 2, color: tokens.textMuted), textAlign: TextAlign.center),
                    ),
                  ...stations.map((s) => PlayerTrackTile(
                    isTV: true,
                    label: s.name.toUpperCase(),
                    isActive: _vm.current?.folder == s.id,
                    onTap: () {
                      _switchStation(s);
                      context.pop();
                    },
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: tokens.background,
        body: Selector<PlayerViewModel, List<Color>?>(
          selector: (_, vm) => vm.vibeColors,
          builder: (context, vibeColors, child) => AtmosphericBackground(
            colors: vibeColors,
            child: child!,
          ),
          child: MouseRegion(
            onHover: (_) => _vm.wakeOSD(),
            child: FocusScope(
              node: _osdFocusScope,
              onKeyEvent: _onKey,
              child: RepaintBoundary(
                key: _repaintKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Selector<PlayerViewModel, (MediaItem?, bool)>(
                      selector: (_, vm) => (vm.current, vm.isLowFiMode),
                      builder: (context, data, _) => GlitchEffect(
                        active: data.$1?.isBroadcast == true || data.$2,
                        child: _buildMediaLayer(context, data.$1),
                      ),
                    ),
                    Selector<PlayerViewModel, (double, String)>(
                      selector: (_, vm) => (vm.gestureOpacity, vm.gestureTxt),
                      builder: (context, data, _) => _buildGestureFeedback(context, data.$1, data.$2),
                    ),
                    Selector<PlayerViewModel, bool>(
                      selector: (_, vm) => vm.showOSD,
                      builder: (context, show, _) => _buildOSD(context, show),
                    ),
                    Selector<PlayerViewModel, String?>(
                      selector: (_, vm) => vm.intercomMessage,
                      builder: (context, msg, _) => _buildIntercomOverlay(context, msg),
                    ),
                    Selector<PlayerViewModel, bool>(
                      selector: (_, vm) => vm.isLowFiMode,
                      builder: (context, lowFi, _) => lowFi ? const LowFiIndicator(isTV: true) : const SizedBox.shrink(),
                    ),
                    if (_showSidebar)
                      GestureDetector(
                        onTap: () => _toggleSidebar(false),
                        child: Container(color: tokens.background.withValues(alpha: 0.6)),
                      ),
                    _buildToolsSidebar(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }



  // ── Media Layers ──────────────────────────────────────────────────────────

  Widget _buildMediaLayer(BuildContext context, MediaItem? item) {
    final tokens = context.tokens;
    if (item == null) return Center(child: CircularProgressIndicator(color: tokens.accent));

    if (item.isImage) return _buildImageLayout(context, item);
    if (item.isAudio) return _buildAudioLayout(context, item);
    return _buildVideoLayout(context, item);
  }

  Widget _buildVideoLayout(BuildContext context, MediaItem item) {
    final tokens = context.tokens;
    return Container(
      color: tokens.background,
      child: Video(
        controller: _vm.videoController,
        controls: NoVideoControls,
        fit: _vm.videoFit,
      ),
    );
  }



  Widget _buildAudioLayout(BuildContext context, MediaItem item) {
    final tokens = context.tokens;
    return Container(
      color: tokens.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                color: tokens.surface1,
                border: Border.all(color: tokens.textPrimary, width: 2),
                boxShadow: [
                  BoxShadow(color: tokens.accent.withValues(alpha: 0.1), offset: const Offset(12, 12)),
                ],
              ),
              child: NetworkImageFade(
                url: _vm.thumbUrl,
                fit: BoxFit.cover,
                fallbackIcon: LucideIcons.music,
              ),
            ),
            const SizedBox(height: 60),
            Text(
              item.title.toUpperCase(),
              style: AppTextStyles.barlowBlack(40, spacing: 2, color: tokens.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'SIGNAL_TYPE // AUDIO_STREAM',
              style: AppTextStyles.mono(14, spacing: 4, color: tokens.textMuted),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildImageLayout(BuildContext context, MediaItem item) {
    final tokens = context.tokens;
    return Container(
      color: tokens.background,
      padding: const EdgeInsets.all(60),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.border.withValues(alpha: 0.15), width: 1),
          ),
          child: Image.network(
            _vm.mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => Icon(LucideIcons.image, color: tokens.textMuted, size: 100),
          ),
        ),
      ),
    );
  }



  // ── OSD (VLC Inspired) ────────────────────────────────────────────────────

  Widget _buildOSD(BuildContext context, bool showOSD) {
    final tokens = context.tokens;
    return AnimatedOpacity(
      opacity: showOSD ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: ExcludeFocus(
        excluding: !showOSD,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [tokens.background.withValues(alpha: 0.9), Colors.transparent],
              stops: const [0.0, 0.4],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildVlcBottomControls(context),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildVlcBottomControls(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (size.width * 0.03).clamp(16.0, 40.0),
        vertical: (size.height * 0.04).clamp(16.0, 40.0),
      ),
      child: Selector<PlayerViewModel, (MediaItem?, int, int)>(
        selector: (_, vm) => (vm.current, vm.currentIndex, vm.playlist.length),
        builder: (context, data, _) {
          final item = data.$1;
          final idx = data.$2;
          final total = data.$3;
          final isBroadcast = item?.isBroadcast ?? false;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Progress Bar
              if (item?.isImage == false) ...[
                BrutalistProgressBar(player: _vm.player, compact: false, isReadOnly: isBroadcast),
                SizedBox(height: (size.height * 0.02).clamp(12.0, 24.0)),
              ],
              // 2. Metadata & Controls Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Metadata (Left)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'STREAMZ // ${idx + 1} OF $total',
                              style: AppTextStyles.mono((size.width * 0.008).clamp(9.0, 12.0), spacing: 3, color: tokens.textMuted),
                            ),
                            if (isBroadcast) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                color: tokens.error,
                                child: Text(
                                  AppStrings.live,
                                  style: AppTextStyles.mono(10, weight: FontWeight.bold, spacing: 1, color: tokens.background),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (item?.title ?? '').toUpperCase(),
                          style: AppTextStyles.barlowBlack((size.width * 0.012).clamp(14.0, 20.0), spacing: 1, color: tokens.textPrimary).copyWith(height: 1.1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Playback Controls (Center)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TVVlcBtn(icon: LucideIcons.skipBack, size: (size.width * 0.03).clamp(32.0, 48.0), onTap: _vm.prev),
                      const SizedBox(width: 16),
                      _buildPlayPauseBtn(context),
                      const SizedBox(width: 16),
                      _TVVlcBtn(icon: LucideIcons.skipForward, size: (size.width * 0.03).clamp(32.0, 48.0), onTap: _vm.next),
                    ],
                  ),
                  // Options (Right)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _TVVlcBtn(icon: LucideIcons.subtitles, size: (size.width * 0.025).clamp(28.0, 44.0), onTap: () => _showTrackModal('subtitles')),
                        const SizedBox(width: 12),
                        _TVVlcBtn(icon: LucideIcons.activity, size: (size.width * 0.025).clamp(28.0, 44.0), onTap: () => _showTrackModal('audio')),
                        const SizedBox(width: 12),
                        _TVVlcBtn(icon: LucideIcons.settings2, size: (size.width * 0.025).clamp(28.0, 44.0), onTap: () => _toggleSidebar(true)),
                        const SizedBox(width: 12),
                        _TVVlcBtn(icon: LucideIcons.x, size: (size.width * 0.025).clamp(28.0, 44.0), onTap: () => context.pop(), isDestructive: true),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }



  Widget _buildPlayPauseBtn(BuildContext context) {
    final item = _vm.current;
    if (item?.isImage == true) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);

    return StreamBuilder<bool>(
      stream: _vm.player.stream.playing,
      builder: (_, snap) {
        final playing = snap.data ?? false;
        return _TVVlcBtn(
          icon: playing ? LucideIcons.pause : LucideIcons.play,
          size: (size.width * 0.04).clamp(44.0, 64.0),
          isPrimary: true,
          focusNode: _playPauseFocusNode,
          onTap: () {
            _vm.player.playOrPause();
            _vm.wakeOSD();
          },
        );
      },
    );
  }




  // ── Sidebar & Components ──────────────────────────────────────────────────

  Widget _buildToolsSidebar(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final sidebarWidth = (size.width * 0.25).clamp(300.0, 420.0);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      right: _showSidebar ? 0 : -sidebarWidth,
      top: 0,
      bottom: 0,
      width: sidebarWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface1,
          border: Border(left: BorderSide(color: tokens.textPrimary, width: 2)),
          boxShadow: [
            BoxShadow(color: tokens.background, blurRadius: 40, offset: const Offset(-20, 0)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
              child: Row(
                children: [
                  Icon(LucideIcons.settings2, color: tokens.textPrimary, size: (size.width * 0.02).clamp(20.0, 28.0)),
                  const SizedBox(width: 16),
                  Text('SYSTEM_CONFIG', style: AppTextStyles.barlowBold((size.width * 0.015).clamp(20.0, 28.0), spacing: 2, color: tokens.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _TVSidebarItem(label: 'STATION LIST', icon: LucideIcons.radio, focusNode: _sidebarFirstItemFocusNode, onTap: _showStationModal),
                  _TVSidebarItem(label: 'SUBTITLE TRACKS', icon: LucideIcons.subtitles, onTap: () => _showTrackModal('subtitles')),
                  _TVSidebarItem(label: 'AUDIO TRACKS', icon: LucideIcons.activity, onTap: () => _showTrackModal('audio')),
                  if (!(_vm.current?.isBroadcast ?? false))
                    _TVSidebarItem(label: 'PLAYBACK RATE', icon: LucideIcons.gauge, onTap: _showSpeedModal),
                  _TVSidebarItem(label: 'ASPECT RATIO', icon: LucideIcons.minimize, onTap: _showFitModal),
                  _TVSidebarItem(label: 'SLEEP TIMER', icon: LucideIcons.clock, onTap: _showSleepModal),
                  _TVSidebarItem(label: 'SYNC CALIBRATION', icon: LucideIcons.layers, onTap: _showSyncModal),
                ],
              ),
            ),
            _TVSidebarItem(label: 'EXIT_TOOLS', icon: LucideIcons.chevronRight, isDestructive: true, onTap: () => setState(() => _showSidebar = false)),
          ],
        ),
      ),
    );
  }


  Widget _buildGestureFeedback(BuildContext context, double opacity, String text) {
    final tokens = context.tokens;
    return Center(
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          decoration: BoxDecoration(
            color: tokens.textPrimary,
            border: Border.all(color: tokens.background, width: 4),
          ),
          child: Text(
            text.toUpperCase(),
            style: GoogleFonts.dmMono(color: tokens.background, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
        ),
      ),
    );
  }


  Widget _buildIntercomOverlay(BuildContext context, String? msg) {
    final tokens = context.tokens;
    if (msg == null) return const SizedBox.shrink();

    return Container(
      color: tokens.background.withValues(alpha: 0.9),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(60),
          decoration: BoxDecoration(
            color: tokens.error,
            border: Border.all(color: tokens.textPrimary, width: 8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SYSTEM_PRIORITY_INTERCOM',
                style: GoogleFonts.dmMono(color: tokens.background, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 8),
              ),
              const SizedBox(height: 32),
              Text(
                msg.toUpperCase(),
                style: GoogleFonts.barlowCondensed(color: tokens.background, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ── Modals ────────────────────────────────────────────────────────────────

  void _showTrackModal(String type) {
    final tokens = context.tokens;
    final tracks = type == 'audio' ? _vm.player.state.tracks.audio : _vm.player.state.tracks.subtitle;
    final current = type == 'audio' ? _vm.player.state.track.audio : _vm.player.state.track.subtitle;

    showGeneralDialog(
      context: context,
      barrierColor: tokens.background.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: FocusScope(
          autofocus: true,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 540,
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                    child: Text('${type.toUpperCase()} SIGNAL SELECT', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  if (type == 'subtitles')
                    PlayerTrackTile(isTV: true, label: 'DISABLE SUBTITLES', isActive: current.id == 'no', onTap: () { _vm.setSubtitleTrack(SubtitleTrack.no()); Navigator.pop(ctx); }),
                  ...tracks.map((t) => PlayerTrackTile(
                    isTV: true,
                    label: (t.title ?? t.language ?? t.id).toUpperCase(),
                    isActive: t.id == current.id,
                    onTap: () {
                      type == 'audio' ? _vm.setAudioTrack(t as AudioTrack) : _vm.setSubtitleTrack(t as SubtitleTrack);
                      Navigator.pop(ctx);
                    },
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showSpeedModal() {
    final tokens = context.tokens;
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final current = _vm.player.state.rate;

    showGeneralDialog(
      context: context,
      barrierColor: tokens.background.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: FocusScope(
          autofocus: true,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 440,
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                    child: Text('PLAYBACK RATE', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  ...speeds.map((s) => PlayerTrackTile(
                    isTV: true,
                    label: '${s}X SPEED',
                    isActive: (s - current).abs() < 0.01,
                    onTap: () { _vm.setRate(s); Navigator.pop(ctx); },
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFitModal() {
    final tokens = context.tokens;
    final fits = {BoxFit.contain: 'CONTAIN', BoxFit.cover: 'FILL_COVER', BoxFit.fill: 'STRETCH_FILL'};
    showGeneralDialog(
      context: context,
      barrierColor: tokens.background.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: FocusScope(
          autofocus: true,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 440,
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                    child: Text('ASPECT_CALIBRATION', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  ...fits.entries.map((e) => PlayerTrackTile(
                    isTV: true,
                    label: e.value,
                    isActive: _vm.videoFit == e.key,
                    onTap: () { _vm.setVideoFit(e.key); Navigator.pop(ctx); },
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showSleepModal() {
    final tokens = context.tokens;
    final options = [0, 5, 15, 30, 60, 120];
    showGeneralDialog(
      context: context,
      barrierColor: tokens.background.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: FocusScope(
          autofocus: true,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 440,
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                    child: Text('AUTO_SHUTDOWN', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  ...options.map((m) => PlayerTrackTile(
                    isTV: true,
                    label: m == 0 ? 'DISABLED' : '$m MINUTES',
                    isActive: _vm.sleepMinutesRemaining == m,
                    onTap: () { _vm.setSleepTimer(m); Navigator.pop(ctx); },
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showSyncModal() {
    final tokens = context.tokens;
    showGeneralDialog(
      context: context,
      barrierColor: tokens.background.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: FocusScope(
          autofocus: true,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 440,
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                    child: Text('SYNC_ADJUSTMENT', style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  ListenableBuilder(
                    listenable: _vm,
                    builder: (_, child) => Column(
                      children: [
                        PlayerSyncTile(isTV: true, label: 'AUDIO OFFSET', value: _vm.audioDelay, onChanged: _vm.setAudioDelay),
                        PlayerSyncTile(isTV: true, label: 'SUBTITLE OFFSET', value: _vm.subDelay, onChanged: _vm.setSubtitleDelay),
                      ],
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
// VLC UI COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _TVVlcBtn extends StatefulWidget {

  const _TVVlcBtn({required this.icon, required this.size, this.onTap, this.isPrimary = false, this.isDestructive = false, this.focusNode});
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool isDestructive;
  final FocusNode? focusNode;

  @override
  State<_TVVlcBtn> createState() => _TVVlcBtnState();
}

class _TVVlcBtnState extends State<_TVVlcBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bg = _focused ? (widget.isDestructive ? tokens.error : tokens.textPrimary) : (widget.isPrimary ? tokens.surface2 : Colors.transparent);
    final fg = _focused ? tokens.background : (widget.isDestructive ? tokens.error : tokens.textPrimary);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: _focused ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15), width: _focused ? 4 : 1),
              boxShadow: _focused ? [BoxShadow(color: tokens.textPrimary.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(4, 4))] : [],
            ),
            child: Icon(widget.icon, color: fg, size: widget.size * 0.5),
          ),
        ),
      ),
    );
  }
}

class _TVSidebarItem extends StatefulWidget {

  const _TVSidebarItem({required this.label, required this.icon, required this.onTap, this.isDestructive = false, this.focusNode});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final FocusNode? focusNode;

  @override
  State<_TVSidebarItem> createState() => _TVSidebarItemState();
}

class _TVSidebarItemState extends State<_TVSidebarItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) {
        setState(() => _focused = v);
        handleTVFocusScroll(v, context);
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            decoration: BoxDecoration(
              color: _focused ? (widget.isDestructive ? tokens.error : tokens.textPrimary) : Colors.transparent,
              border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: _focused ? tokens.background : (widget.isDestructive ? tokens.error : tokens.textPrimary), size: 24),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.dmMono(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _focused ? tokens.background : (widget.isDestructive ? tokens.error : tokens.textPrimary),
                      letterSpacing: 2,
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
