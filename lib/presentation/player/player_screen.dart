// presentation/player/player_screen.dart
// ============================================================================
// STREAMZ — Universal Media Player Screen
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
import 'package:streamz/presentation/player/playback_issue.dart';
import 'package:streamz/presentation/player/player_viewmodel.dart';
import 'package:streamz/presentation/player/widgets/low_fi_indicator.dart';
import 'package:streamz/presentation/player/widgets/playback_recovery_overlay.dart';
import 'package:streamz/presentation/player/widgets/player_action_button.dart';
import 'package:streamz/presentation/player/widgets/player_options_sheet.dart';
import 'package:streamz/presentation/player/widgets/player_sync_tile.dart';
import 'package:streamz/presentation/player/widgets/player_track_tile.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
import 'package:streamz/presentation/shared/media_details_text.dart';
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
    _vm
        .load(
          items: widget.items,
          startIndex: widget.startIndex,
          isPathBased: widget.isPathBased,
          startOffset: widget.startOffset,
          autoPlay: widget.autoPlay,
        )
        .then((_) {
          _primaryFocusNode.requestFocus();
        });
    _vm.snapshotCallback = _captureSnapshot;
    _wasOSDVisible = _vm.showOSD;
    _vm.addListener(_onVMChange);
  }

  Future<String?> _captureSnapshot() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(
        pixelRatio: 0.1,
      ); // Low res for mobile
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
    if (key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.space) {
      if (!_vm.player.state.playing) {
        _vm.play();
      } else if (key == LogicalKeyboardKey.space) {
        _vm.pause();
      }
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      _vm
        ..pause()
        ..wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      _vm
        ..togglePlayback()
        ..wakeOSD();
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
      unawaited(
        _vm.load(
          items: res.playlist,
          startIndex: res.itemIndex,
          isPathBased: false,
          startOffset: res.position,
          autoPlay: !res.isPaused,
        ),
      );
    }
  }

  void _showStationModal() {
    final clientVM = context.read<ClientViewModel>();
    final stations = clientVM.stations;

    showPlayerOptionsSheet<void>(
      context: context,
      isTV: false,
      title: AppStrings.networkBroadcasts,
      subtitle: 'Join a live broadcast on your network.',
      icon: LucideIcons.radio,
      maxWidth: 500,
      contentBuilder: (sheetContext) => stations.isEmpty
          ? const AppStateView(
              title: 'No active broadcasts',
              description: 'Live stations will appear here when available.',
              icon: LucideIcons.radioTower,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final station in stations)
                  AppListTileCard(
                    title: station.name,
                    subtitle: station.nowPlaying == null
                        ? AppStrings.awaitingSignal
                        : '${AppStrings.statusNowPlaying} · ${station.nowPlaying!.item.title}',
                    icon: LucideIcons.radio,
                    isActive: _vm.current?.folder == station.id,
                    onTap: () {
                      _switchStation(station);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
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
      child: AppScaffold(
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
                _vm.seekRelative(
                  Duration(seconds: d.globalPosition.dx < half ? -10 : 10),
                );
              },
              onHorizontalDragUpdate: (d) {
                final dur = _vm.player.state.duration.inSeconds;
                if (item?.isImage == true ||
                    item?.isBroadcast == true ||
                    dur <= 0) {
                  return;
                }
                final factor =
                    d.primaryDelta! / MediaQuery.sizeOf(context).width;
                final scrubSec = (factor * dur).toInt();
                if (scrubSec != 0) {
                  _vm.player.seek(
                    _vm.player.state.position + Duration(seconds: scrubSec),
                  );
                }
              },
              child: RepaintBoundary(
                key: _repaintKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildMediaLayer(context),
                    _buildGestureFeedback(context),
                    _buildOSD(context),
                    _buildIntercomOverlay(context),
                    if (_vm.isLowFiMode) const LowFiIndicator(isTV: false),
                    if (_showTechnicalOverlay)
                      Positioned(
                        top: DS.s80,
                        right: DS.s16,
                        width: (MediaQuery.sizeOf(context).width - DS.s32)
                            .clamp(1.0, 320.0)
                            .toDouble(),
                        height: (MediaQuery.sizeOf(context).height - DS.s96)
                            .clamp(1.0, 400.0)
                            .toDouble(),
                        child: TechnicalOverlay(
                          stats: {
                            'Title': item?.title ?? 'Unavailable',
                            'Type': item?.isVideo == true
                                ? 'Video'
                                : (item?.isAudio == true ? 'Audio' : 'Image'),
                            'Position': _vm.player.state.position
                                .toString()
                                .split('.')
                                .first,
                            'Duration': _vm.player.state.duration
                                .toString()
                                .split('.')
                                .first,
                            'Volume': '${_vm.player.state.volume.toInt()}%',
                            'Speed': '${_vm.player.state.rate}×',
                            'Buffer': '${_vm.player.state.buffer.inSeconds} sec',
                          },
                          onClose: () =>
                              setState(() => _showTechnicalOverlay = false),
                        ),
                      ),
                    if (_showSidebar)
                      GestureDetector(
                        onTap: () => setState(() => _showSidebar = false),
                        child: Container(
                          color: tokens.background.withValues(alpha: 0.6),
                        ),
                      ),
                    _buildToolsSidebar(context),
                    Selector<
                      PlayerViewModel,
                      (PlaybackIssue?, bool, bool, int, Duration)
                    >(
                      selector: (_, vm) => (
                        vm.playbackIssue,
                        vm.isRecovering,
                        vm.isRetryInFlight,
                        vm.retryAttempt,
                        vm.recoveryPosition,
                      ),
                      builder: (context, state, _) {
                        final issue = state.$1;
                        if (issue == null) return const SizedBox.shrink();
                        return PlaybackRecoveryOverlay(
                          issue: issue,
                          isRecovering: state.$2,
                          isRetryInFlight: state.$3,
                          retryAttempt: state.$4,
                          resumePosition: state.$5,
                          isTV: false,
                          onRetry: () => _vm.retryPlayback(),
                          onBack: () => context.pop(),
                        );
                      },
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

  // ── Media Layers ──────────────────────────────────────────────────────────

  Widget _buildMediaLayer(BuildContext context) {
    final tokens = context.tokens;
    final item = _vm.current;
    if (item == null) {
      return Center(child: CircularProgressIndicator(color: tokens.accent));
    }

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final sz =
            (isLandscape
                    ? constraints.maxHeight * 0.4
                    : constraints.maxWidth * 0.5)
                .clamp(120.0, 300.0);

        return Container(
          color: tokens.background,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(DS.radius(22)),
                  child: Container(
                    width: sz,
                    height: sz,
                    decoration: BoxDecoration(
                      color: tokens.surface1,
                      borderRadius: BorderRadius.circular(DS.radius(22)),
                      border: Border.all(
                        color: tokens.border.withValues(alpha: 0.65),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.accent.withValues(alpha: 0.1),
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: NetworkImageFade(
                      url: _vm.thumbUrl,
                      fit: BoxFit.cover,
                      fallbackIcon: LucideIcons.music,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    item.title,
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontWeight: AppTextStyles.titleFontWeight,
                      letterSpacing: -0.3,
                      color: tokens.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Audio stream',
                  style: AppTextStyles.caption.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageLayout(BuildContext context, MediaItem item) {
    final tokens = context.tokens;
    return Container(
      color: tokens.background,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: tokens.border.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Image.network(
            _vm.mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) =>
                Icon(LucideIcons.image, color: tokens.textMuted, size: 64),
          ),
        ),
      ),
    );
  }

  // ── OSD (Mobile VLC Style) ────────────────────────────────────────────────

  Widget _buildOSD(BuildContext context) => IgnorePointer(
    ignoring: !_vm.showOSD,
    child: AnimatedOpacity(
      opacity: _vm.showOSD ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: ExcludeFocus(
        excluding: !_vm.showOSD,
        child: Stack(
          children: [
            _buildTopBar(context),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_buildVlcBottomControls(context)],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildTopBar(BuildContext context) {
    final tokens = context.tokens;
    final item = _vm.current;
    final nextItem = _vm.currentIndex + 1 < _vm.playlist.length
        ? _vm.playlist[_vm.currentIndex + 1]
        : null;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          12,
          MediaQuery.paddingOf(context).top + 4,
          12,
          12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.background.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            PlayerActionButton(
              icon: AppIcons.back,
              label: 'Back',
              size: 48,
              onPressed: () => context.pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item?.title ?? '',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item != null) MediaDetailsText(item: item),
                  Row(
                    children: [
                      Text(
                        '${_vm.currentIndex + 1} of ${_vm.playlist.length}',
                        style: AppTextStyles.caption.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                      if (item?.isBroadcast == true) ...[
                        const SizedBox(width: DS.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DS.s8,
                            vertical: DS.s4,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.error,
                            borderRadius: BorderRadius.circular(DS.radiusLg),
                          ),
                          child: Text(
                            AppStrings.live,
                            style: AppTextStyles.caption.copyWith(
                              color: tokens.background,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (nextItem != null)
                    Semantics(
                      button: true,
                      label: '${AppStrings.upNext}: ${nextItem.title}',
                      child: InkWell(
                        onTap: _vm.next,
                        borderRadius: BorderRadius.circular(DS.radius(8)),
                        child: SizedBox(
                          height: 40,
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.skipForward,
                                size: 14,
                                color: tokens.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${AppStrings.upNext} · ${nextItem.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: tokens.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PlayerActionButton(
              icon: LucideIcons.settings2,
              label: 'Player options',
              size: 48,
              onPressed: () {
                setState(() => _showSidebar = true);
                _sidebarFirstItemFocusNode.requestFocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVlcBottomControls(BuildContext context) {
    final tokens = context.tokens;
    final item = _vm.current;
    final isBroadcast = item?.isBroadcast ?? false;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 12,
        12,
        compact ? 8 : 12,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            tokens.background.withValues(alpha: 0.9),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item?.isImage == false) ...[
            PlayerProgressBar(
              player: _vm.player,
              compact: true,
              isReadOnly: isBroadcast,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayerActionButton(
                icon: LucideIcons.skipBack,
                label: 'Previous item',
                size: 28,
                onPressed: _vm.prev,
              ),
              SizedBox(width: compact ? 8 : 16),
              _buildPlayPauseBtn(context),
              SizedBox(width: compact ? 8 : 16),
              PlayerActionButton(
                icon: LucideIcons.skipForward,
                label: 'Next item',
                size: 28,
                onPressed: _vm.next,
              ),
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
        return PlayerActionButton(
          icon: playing ? LucideIcons.pause : LucideIcons.play,
          label: playing ? 'Pause' : 'Play',
          size: 44,
          isPrimary: true,
          onPressed: () {
            _vm
              ..togglePlayback()
              ..wakeOSD();
          },
        );
      },
    );
  }

  // ── Sidebar & Feedbacks ───────────────────────────────────────────────────

  Widget _buildToolsSidebar(BuildContext context) {
    final tokens = context.tokens;
    final sidebarWidth = (MediaQuery.sizeOf(context).width * 0.28).clamp(
      240.0,
      360.0,
    );
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
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(DS.radius(22)),
          ),
          border: Border(
            left: BorderSide(color: tokens.border.withValues(alpha: 0.7)),
          ),
          boxShadow: [BoxShadow(color: tokens.background, blurRadius: 20)],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: tokens.border.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.settings2,
                      color: tokens.textPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Options',
                      style: AppTextStyles.title.copyWith(
                        fontWeight: AppTextStyles.titleFontWeight,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _MobileSidebarItem(
                      label: 'Station list',
                      icon: LucideIcons.radio,
                      focusNode: _sidebarFirstItemFocusNode,
                      onTap: _showStationModal,
                    ),
                    _MobileSidebarItem(
                      label: 'Technical stats',
                      icon: LucideIcons.activity,
                      onTap: () {
                        setState(() {
                          _showTechnicalOverlay = true;
                          _showSidebar = false;
                        });
                      },
                    ),
                    _MobileSidebarItem(
                      label: 'Subtitles',
                      icon: LucideIcons.subtitles,
                      onTap: () => _showTrackModal(context, 'subtitles'),
                    ),
                    _MobileSidebarItem(
                      label: 'Audio tracks',
                      icon: LucideIcons.activity,
                      onTap: () => _showTrackModal(context, 'audio'),
                    ),
                    if (!(_vm.current?.isBroadcast ?? false))
                      _MobileSidebarItem(
                        label: 'Playback speed',
                        icon: LucideIcons.gauge,
                        onTap: () => _showSpeedModal(context),
                      ),
                    _MobileSidebarItem(
                      label: 'Aspect ratio',
                      icon: LucideIcons.minimize,
                      onTap: () => _showFitModal(context),
                    ),
                    _MobileSidebarItem(
                      label: 'Sleep timer',
                      icon: LucideIcons.clock,
                      onTap: () => _showSleepModal(context),
                    ),
                    _MobileSidebarItem(
                      label: 'Sync adjustment',
                      icon: LucideIcons.layers,
                      onTap: () => _showSyncModal(context),
                    ),
                  ],
                ),
              ),
              _MobileSidebarItem(
                label: 'Close',
                icon: LucideIcons.chevronRight,
                isDestructive: true,
                onTap: () => setState(() => _showSidebar = false),
              ),
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
          decoration: BoxDecoration(
            color: tokens.textPrimary,
            borderRadius: BorderRadius.circular(DS.radius(16)),
          ),
          child: Text(
            _vm.gestureTxt,
            style: AppTextStyles.caption.copyWith(
              color: tokens.background,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
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
            borderRadius: BorderRadius.circular(DS.radius(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Emergency broadcast',
                style: AppTextStyles.caption.copyWith(
                  color: tokens.background,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                msg,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: tokens.background,
                  fontWeight: AppTextStyles.titleFontWeight,
                ),
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
    final tracks = type == 'audio'
        ? _vm.player.state.tracks.audio
        : _vm.player.state.tracks.subtitle;
    final current = type == 'audio'
        ? _vm.player.state.track.audio
        : _vm.player.state.track.subtitle;

    showPlayerOptionsSheet<void>(
      context: context,
      isTV: false,
      title: type == 'audio' ? 'Audio tracks' : 'Subtitles',
      subtitle: type == 'audio'
          ? 'Choose the audio track for this media.'
          : 'Choose a subtitle track or turn subtitles off.',
      icon: type == 'audio' ? LucideIcons.audioLines : LucideIcons.subtitles,
      maxWidth: 480,
      contentBuilder: (sheetContext) {
        if (type == 'audio' && tracks.isEmpty) {
          return const AppStateView(
            title: 'No audio tracks',
            description: 'This media does not provide alternate audio tracks.',
            icon: LucideIcons.audioLines,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'subtitles')
              PlayerTrackTile(
                label: 'Disabled',
                isActive: current.id == 'no',
                onTap: () {
                  _vm.setSubtitleTrack(SubtitleTrack.no());
                  Navigator.pop(sheetContext);
                },
              ),
            for (final track in tracks)
              PlayerTrackTile(
                label: track.title ?? track.language ?? track.id,
                isActive: track.id == current.id,
                onTap: () {
                  type == 'audio'
                      ? _vm.setAudioTrack(track as AudioTrack)
                      : _vm.setSubtitleTrack(track as SubtitleTrack);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        );
      },
    );
  }

  void _showSpeedModal(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final current = _vm.player.state.rate;

    showPlayerOptionsSheet<void>(
      context: context,
      isTV: false,
      title: 'Playback speed',
      subtitle: 'Adjust the playback rate.',
      icon: LucideIcons.gauge,
      maxWidth: 400,
      contentBuilder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final speed in speeds)
            PlayerTrackTile(
              label: '$speed× speed',
              isActive: (speed - current).abs() < 0.01,
              onTap: () {
                _vm.setRate(speed);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    );
  }

  void _showFitModal(BuildContext context) {
    final fits = {
      BoxFit.contain: 'Contain',
      BoxFit.cover: 'Cover',
      BoxFit.fill: 'Stretch',
    };
    showPlayerOptionsSheet<void>(
      context: context,
      isTV: false,
      title: 'Aspect ratio',
      subtitle: 'Choose how the picture fits the screen.',
      icon: LucideIcons.scan,
      maxWidth: 400,
      contentBuilder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final fit in fits.entries)
            PlayerTrackTile(
              label: fit.value,
              isActive: _vm.videoFit == fit.key,
              onTap: () {
                _vm.setVideoFit(fit.key);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    );
  }

  void _showSleepModal(BuildContext context) {
    final options = [0, 5, 15, 30, 60, 120];
    showPlayerOptionsSheet<void>(
      context: context,
      isTV: false,
      title: 'Sleep timer',
      subtitle: 'Stop playback after a set time.',
      icon: LucideIcons.clock,
      maxWidth: 400,
      contentBuilder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final minutes in options)
            PlayerTrackTile(
              label: minutes == 0 ? 'Off' : '$minutes minutes',
              isActive: _vm.sleepMinutesRemaining == minutes,
              onTap: () {
                _vm.setSleepTimer(minutes);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    );
  }

  void _showSyncModal(BuildContext context) {
    showPlayerOptionsSheet<void>(
      context: context,
      isTV: false,
      title: 'Sync adjustment',
      subtitle: 'Fine-tune audio and subtitle timing.',
      icon: LucideIcons.layers,
      maxWidth: 480,
      contentBuilder: (_) => ListenableBuilder(
        listenable: _vm,
        builder: (_, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerSyncTile(
              label: 'Audio offset',
              value: _vm.audioDelay,
              onChanged: _vm.setAudioDelay,
            ),
            PlayerSyncTile(
              label: 'Subtitle offset',
              value: _vm.subDelay,
              onChanged: _vm.setSubtitleDelay,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE UI SUB-COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _MobileSidebarItem extends StatefulWidget {
  const _MobileSidebarItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.focusNode,
  });
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
    final color = widget.isDestructive ? tokens.error : tokens.textPrimary;
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
            color: _focused ? tokens.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(DS.radius(12)),
            border: Border(
              bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 14),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
