// presentation/player/player_screen.dart
// ============================================================================
// STREAMZ — Universal Media Player Screen (VLC-Inspired Brutalist Edition)
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
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/domain/models/broadcast_station.dart';
import 'package:streamz/domain/models/media_item.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/player/player_viewmodel.dart';
import 'package:streamz/presentation/player/widgets/low_fi_indicator.dart';
import 'package:streamz/presentation/player/widgets/player_sync_tile.dart';
import 'package:streamz/presentation/player/widgets/player_track_tile.dart';
import 'package:streamz/widget/glitch_effect.dart';
import 'package:streamz/widget/technical_overlay.dart';


class PlayerScreen extends StatefulWidget {

  const PlayerScreen({
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
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerViewModel _vm;
  final GlobalKey _repaintKey = GlobalKey();

  final FocusScopeNode _osdFocusScope = FocusScopeNode();
  final FocusNode _primaryFocusNode = FocusNode();
  final FocusNode _sidebarFirstItemFocusNode = FocusNode();

  bool _wasOSDVisible = true;
  bool _showSidebar = false;
  bool _showTechnicalOverlay = false;

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
      _primaryFocusNode.requestFocus();
    });
    _vm.snapshotCallback = _captureSnapshot;
    _wasOSDVisible = _vm.showOSD;
    _vm.addListener(_onVMChange);
  }

  Future<String?> _captureSnapshot() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 0.1); // Low res for mobile
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
        _primaryFocusNode.requestFocus();
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _vm
      ..removeListener(_onVMChange)
      ..dispose();
    _osdFocusScope.dispose();
    _primaryFocusNode.dispose();
    _sidebarFirstItemFocusNode.dispose();
    super.dispose();
  }

  // ── Key handling (Keyboard & Remote) ──────────────────────────────────────

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final item = _vm.current;

    // 1. GLOBAL NAVIGATION & EXIT
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.exit) {
      if (_showSidebar) {
        setState(() => _showSidebar = false);
        _primaryFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_vm.showOSD) {
        _vm.hideOSD();
        return KeyEventResult.handled;
      }
      Navigator.pop(context);
      return KeyEventResult.handled;
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

    // 3. DEDICATED MEDIA KEYS
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

    // 4. INFO & SIDEBAR
    if (key == LogicalKeyboardKey.info || key == LogicalKeyboardKey.guide) {
      setState(() => _showTechnicalOverlay = !_showTechnicalOverlay);
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu) {
      setState(() => _showSidebar = true);
      _sidebarFirstItemFocusNode.requestFocus();
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }

    // 5. OSD-HIDDEN SPECIFIC KEYS
    if (!_vm.showOSD) {
      _vm.wakeOSD();

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
      // On non-TV, we might want Select/Enter to toggle play/pause even if OSD is hidden,
      // but to keep it consistent and less jarring, let's just wake OSD first.
      return KeyEventResult.handled;
    }

    // 6. OSD-VISIBLE KEYS (Delegate to Focus System)
    _vm.wakeOSD();
    return KeyEventResult.ignored;
  }

  // ── Station Switching ─────────────────────────────────────────────────────

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
              width: MediaQuery.sizeOf(context).width * 0.85,
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                    child: Text('LIVE STATIONS', style: AppTextStyles.barlowBold(24, spacing: 2, color: tokens.textPrimary)),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: stations.map((s) => PlayerTrackTile(
                        label: s.name.toUpperCase(),
                        isActive: _vm.current?.folder == s.id,
                        onTap: () {
                          _switchStation(s);
                          context.pop();
                        },
                      )).toList(),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final item = _vm.current;
    if (item?.isVideo == true) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: tokens.background,
        body: MouseRegion(
          onHover: (_) => _vm.wakeOSD(),
          child: FocusScope(
            node: _osdFocusScope,
            onKeyEvent: _onKey,
            child: GestureDetector(
              onTap: () => _vm.toggleOSD(),
              onDoubleTapDown: (d) {
                if (item?.isBroadcast == true) return;
                final half = MediaQuery.sizeOf(context).width / 2;
                _vm.seekRelative(Duration(seconds: d.globalPosition.dx < half ? -10 : 10));
              },
              onHorizontalDragUpdate: (d) {
                final dur = _vm.player.state.duration.inSeconds;
                if (item?.isImage == true || item?.isBroadcast == true || dur <= 0) return;
                final factor = d.primaryDelta! / MediaQuery.sizeOf(context).width;
                final scrubSec = (factor * dur).toInt();
                if (scrubSec != 0) {
                  _vm.player.seek(_vm.player.state.position + Duration(seconds: scrubSec));
                }
              },
              child: RepaintBoundary(
                key: _repaintKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GlitchEffect(
                      active: item?.isBroadcast == true || _vm.isLowFiMode,
                      child: _buildMediaLayer(context),
                    ),
                    _buildGestureFeedback(context),
                    _buildOSD(context),
                    _buildIntercomOverlay(context),
                    if (_vm.isLowFiMode) const LowFiIndicator(isTV: false),
                    if (_showTechnicalOverlay)
                      Positioned(
                        top: DS.s80,
                        right: DS.s24,
                        width: 320,
                        height: 400,
                        child: TechnicalOverlay(
                          stats: {
                            'TITLE': item?.title ?? 'N/A',
                            'TYPE': item?.isVideo == true ? 'VIDEO' : (item?.isAudio == true ? 'AUDIO' : 'IMAGE'),
                            'POSITION': _vm.player.state.position.toString().split('.').first,
                            'DURATION': _vm.player.state.duration.toString().split('.').first,
                            'VOLUME': '${_vm.player.state.volume.toInt()}%',
                            'RATE': '${_vm.player.state.rate}X',
                            'BUFFER': '${_vm.player.state.buffer.inSeconds}S',
                          },
                          onClose: () => setState(() => _showTechnicalOverlay = false),
                        ),
                      ),
                    if (_showSidebar)
                      GestureDetector(
                        onTap: () => setState(() => _showSidebar = false),
                        child: Container(color: tokens.background.withValues(alpha: 0.6)),
                      ),
                    _buildToolsSidebar(context),
                  ],
                ),
              ),
          ),
        ),
      ),
      ));
  }

  // ── Media Layers ──────────────────────────────────────────────────────────

  Widget _buildMediaLayer(BuildContext context) {
    final tokens = context.tokens;
    final item = _vm.current;
    if (item == null) return Center(child: CircularProgressIndicator(color: tokens.accent));

    if (item.isImage) return _buildImageLayout(context, item);
    if (item.isAudio) return _buildAudioLayout(context, item);
    return _buildVideoLayout(context, item);
  }

  Widget _buildVideoLayout(BuildContext context, MediaItem item) => Container(
      color: Colors.black,
      child: Video(
        controller: _vm.videoController,
        controls: NoVideoControls,
        fit: _vm.videoFit,
      ),
    );



  Widget _buildAudioLayout(BuildContext context, MediaItem item) {
    final tokens = context.tokens;
    return LayoutBuilder(builder: (context, constraints) {
      final isLandscape = constraints.maxWidth > constraints.maxHeight;
      final sz = (isLandscape ? constraints.maxHeight * 0.4 : constraints.maxWidth * 0.5).clamp(120.0, 300.0);

      return Container(
        color: tokens.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: sz,
                height: sz,
                decoration: BoxDecoration(
                  color: tokens.surface1,
                  border: Border.all(color: tokens.textPrimary, width: 1),
                  boxShadow: [
                    BoxShadow(color: tokens.accent.withValues(alpha: 0.1), offset: const Offset(4, 4)),
                  ],
                ),
                child: NetworkImageFade(
                  url: _vm.thumbUrl,
                  fit: BoxFit.cover,
                  fallbackIcon: LucideIcons.music,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  item.title.toUpperCase(),
                  style: AppTextStyles.barlowBlack(22, spacing: 1, color: tokens.textPrimary),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SIGNAL_TYPE // AUDIO_STREAM',
                style: AppTextStyles.mono(8, spacing: 2, color: tokens.textMuted),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildImageLayout(BuildContext context, MediaItem item) {
    final tokens = context.tokens;
    return Container(
      color: tokens.background,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: tokens.border.withValues(alpha: 0.15), width: 1)),
          child: Image.network(
            _vm.mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => Icon(LucideIcons.image, color: tokens.textMuted, size: 64),
          ),
        ),
      ),
    );
  }


  // ── OSD (Mobile VLC Style) ────────────────────────────────────────────────

  Widget _buildOSD(BuildContext context) => AnimatedOpacity(
      opacity: _vm.showOSD ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: ExcludeFocus(
        excluding: !_vm.showOSD,
        child: Stack(
          children: [
            _buildTopBar(context),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildVlcBottomControls(context),
              ],
            ),
          ],
        ),
      ),
    );


  Widget _buildTopBar(BuildContext context) {
    final tokens = context.tokens;
    final item = _vm.current;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 4, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tokens.background.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            _MobileIconBtn(icon: AppIcons.back, size: 32, onTap: () => context.pop()),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (item?.title ?? '').toUpperCase(),
                    style: AppTextStyles.barlowBold(14, spacing: 1, color: tokens.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'CMD // ${_vm.currentIndex + 1} OF ${_vm.playlist.length}',
                    style: AppTextStyles.mono(8, spacing: 1, color: tokens.textMuted),
                  ),
                ],
              ),
            ),
            _MobileIconBtn(icon: LucideIcons.settings2, size: 32, onTap: () {
              setState(() => _showSidebar = true);
              _sidebarFirstItemFocusNode.requestFocus();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVlcBottomControls(BuildContext context) {
    final tokens = context.tokens;
    final item = _vm.current;
    final isBroadcast = item?.isBroadcast ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.paddingOf(context).bottom + 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [tokens.background.withValues(alpha: 0.9), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item?.isImage == false) ...[
            BrutalistProgressBar(player: _vm.player, compact: true, isReadOnly: isBroadcast),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              _MobileIconBtn(icon: LucideIcons.subtitles, size: 28, onTap: () => _showTrackModal(context, 'subtitles')),
              const SizedBox(width: 4),
              if (isBroadcast)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  color: tokens.error,
                  child: Text(AppStrings.live, style: AppTextStyles.mono(8, weight: FontWeight.bold, color: tokens.background)),
                ),

              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MobileIconBtn(icon: LucideIcons.skipBack, size: 28, onTap: _vm.prev),
                  const SizedBox(width: 16),
                  _buildPlayPauseBtn(context),
                  const SizedBox(width: 16),
                  _MobileIconBtn(icon: LucideIcons.skipForward, size: 28, onTap: _vm.next),
                ],
              ),
              const Spacer(),

              _MobileIconBtn(icon: LucideIcons.activity, size: 28, onTap: () => _showTrackModal(context, 'audio')),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildPlayPauseBtn(BuildContext context) {
    final item = _vm.current;
    if (item?.isImage == true) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: _vm.player.stream.playing,
      builder: (_, snap) {
        final playing = snap.data ?? false;
        return _MobileIconBtn(
          icon: playing ? LucideIcons.pause : LucideIcons.play,
          size: 44,
          isPrimary: true,
          onTap: () {
            _vm.player.playOrPause();
            _vm.wakeOSD();
          },
        );
      },
    );
  }


  // ── Sidebar & Feedbacks ───────────────────────────────────────────────────

  Widget _buildToolsSidebar(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      right: _showSidebar ? 0 : -220,
      top: 0,
      bottom: 0,
      width: 220,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface1,
          border: Border(left: BorderSide(color: tokens.textPrimary, width: 1)),
          boxShadow: [BoxShadow(color: tokens.background, blurRadius: 20)],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                child: Row(
                  children: [
                    Icon(LucideIcons.settings2, color: tokens.textPrimary, size: 16),
                    const SizedBox(width: 8),
                    Text('TOOLS', style: AppTextStyles.barlowBold(18, spacing: 1, color: tokens.textPrimary)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _MobileSidebarItem(label: 'STATION LIST', icon: LucideIcons.radio, focusNode: _sidebarFirstItemFocusNode, onTap: _showStationModal),
                    _MobileSidebarItem(label: 'TECHNICAL STATS', icon: LucideIcons.activity, onTap: () {
                      setState(() {
                        _showTechnicalOverlay = true;
                        _showSidebar = false;
                      });
                    }),
                    _MobileSidebarItem(label: 'SUBTITLES', icon: LucideIcons.subtitles, onTap: () => _showTrackModal(context, 'subtitles')),
                    _MobileSidebarItem(label: 'AUDIO TRACKS', icon: LucideIcons.activity, onTap: () => _showTrackModal(context, 'audio')),
                    if (!(_vm.current?.isBroadcast ?? false))
                      _MobileSidebarItem(label: 'SPEED', icon: LucideIcons.gauge, onTap: () => _showSpeedModal(context)),
                    _MobileSidebarItem(label: 'ASPECT', icon: LucideIcons.minimize, onTap: () => _showFitModal(context)),
                    _MobileSidebarItem(label: 'SLEEP TIMER', icon: LucideIcons.clock, onTap: () => _showSleepModal(context)),
                    _MobileSidebarItem(label: 'SYNC ADJUST', icon: LucideIcons.layers, onTap: () => _showSyncModal(context)),
                  ],
                ),
              ),
              _MobileSidebarItem(label: 'CLOSE', icon: LucideIcons.chevronRight, isDestructive: true, onTap: () => setState(() => _showSidebar = false)),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildGestureFeedback(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: AnimatedOpacity(
        opacity: _vm.gestureOpacity,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: tokens.textPrimary, border: Border.all(color: tokens.background, width: 1)),
          child: Text(
            _vm.gestureTxt.toUpperCase(),
            style: GoogleFonts.dmMono(color: tokens.background, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ),
      ),
    );
  }


  Widget _buildIntercomOverlay(BuildContext context) {
    final tokens = context.tokens;
    final msg = _vm.intercomMessage;
    if (msg == null) return const SizedBox.shrink();

    return Container(
      color: tokens.background.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: tokens.error,
            border: Border.all(color: tokens.textPrimary, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EMERGENCY BROADCAST',
                style: GoogleFonts.dmMono(color: tokens.background, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: 16),
              Text(
                msg.toUpperCase(),
                style: GoogleFonts.barlowCondensed(color: tokens.background, fontSize: 24, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ── Modals ────────────────────────────────────────────────────────────────

  void _showTrackModal(BuildContext context, String type) {
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
              width: MediaQuery.sizeOf(context).width * 0.85,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)))),
                    child: Text(type.toUpperCase(), style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  if (type == 'subtitles')
                    PlayerTrackTile(label: 'DISABLED', isActive: current.id == 'no', onTap: () { _vm.setSubtitleTrack(SubtitleTrack.no()); Navigator.pop(ctx); }),
                  ...tracks.map((t) => PlayerTrackTile(
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


  void _showSpeedModal(BuildContext context) {
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
              width: MediaQuery.sizeOf(context).width * 0.8,
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: speeds.map((s) => PlayerTrackTile(
                  label: '${s}X SPEED',
                  isActive: (s - current).abs() < 0.01,
                  onTap: () { _vm.setRate(s); Navigator.pop(ctx); },
                )).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showFitModal(BuildContext context) {
    final tokens = context.tokens;
    final fits = {BoxFit.contain: 'CONTAIN', BoxFit.cover: 'COVER', BoxFit.fill: 'STRETCH'};
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
              width: MediaQuery.sizeOf(context).width * 0.8,
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fits.entries.map((e) => PlayerTrackTile(
                  label: e.value,
                  isActive: _vm.videoFit == e.key,
                  onTap: () { _vm.setVideoFit(e.key); Navigator.pop(ctx); },
                )).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showSleepModal(BuildContext context) {
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
              width: MediaQuery.sizeOf(context).width * 0.8,
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((m) => PlayerTrackTile(
                  label: m == 0 ? 'OFF' : '$m MINUTES',
                  isActive: _vm.sleepMinutesRemaining == m,
                  onTap: () { _vm.setSleepTimer(m); Navigator.pop(ctx); },
                )).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showSyncModal(BuildContext context) {
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
              width: MediaQuery.sizeOf(context).width * 0.9,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(color: tokens.surface1, border: Border.all(color: tokens.textPrimary, width: 2)),
              child: ListenableBuilder(
                listenable: _vm,
                builder: (_, child) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerSyncTile(label: 'AUDIO OFFSET', value: _vm.audioDelay, onChanged: _vm.setAudioDelay),
                    PlayerSyncTile(label: 'SUBTITLE OFFSET', value: _vm.subDelay, onChanged: _vm.setSubtitleDelay),
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
// MOBILE UI SUB-COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _MobileIconBtn extends StatefulWidget {

  const _MobileIconBtn({required this.icon, required this.onTap, this.size = 44, this.isPrimary = false}) : isDestructive = false;
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isPrimary;
  final bool isDestructive;

  @override
  State<_MobileIconBtn> createState() => _MobileIconBtnState();
}

class _MobileIconBtnState extends State<_MobileIconBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _focused ? tokens.textPrimary : (widget.isPrimary ? tokens.textPrimary : Colors.transparent),
            border: Border.all(color: _focused ? tokens.textPrimary : tokens.border.withValues(alpha: 0.15)),
          ),
          child: Icon(widget.icon, color: _focused ? tokens.background : (widget.isPrimary ? tokens.background : tokens.textPrimary), size: widget.size * 0.5),
        ),
      ),
    );
  }
}

class _MobileSidebarItem extends StatefulWidget {

  const _MobileSidebarItem({required this.label, required this.icon, required this.onTap, this.isDestructive = false, this.focusNode});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final FocusNode? focusNode;

  @override
  State<_MobileSidebarItem> createState() => _MobileSidebarItemState();
}

class _MobileSidebarItemState extends State<_MobileSidebarItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = widget.isDestructive ? tokens.error : (_focused ? tokens.background : tokens.textPrimary);
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) {
        setState(() => _focused = v);
        handleTVFocusScroll(v, context);
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _focused ? tokens.textPrimary : Colors.transparent,
            border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 14),
              const SizedBox(width: 12),
              Text(widget.label, style: GoogleFonts.dmMono(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}
