// presentation/tv/tv_player_screen.dart
// ============================================================================
// STREAMZ — TV Dedicated Media Player
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
    _vm
        .load(
          items: widget.items,
          startIndex: widget.startIndex,
          isPathBased: widget.isPathBased,
          startOffset: widget.startOffset,
          autoPlay: widget.autoPlay,
        )
        .then((_) {
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
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(
        pixelRatio: 0.15,
      ); // Low res for speed
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
    _vm
      ..removeListener(_onVMChange)
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

  bool _isExitKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.escape ||
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

  KeyEventResult _handleDedicatedMediaKeys(
    LogicalKeyboardKey key,
    MediaItem? item,
  ) {
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
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleHiddenOSDKeys(LogicalKeyboardKey key, MediaItem? item) {
    _vm.wakeOSD();

    // Channel Switching
    if (key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.pageUp) {
      _cycleStation(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageDown) {
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
      isTV: true,
      title: AppStrings.networkBroadcasts,
      subtitle: 'Join a live broadcast on your network.',
      icon: LucideIcons.radio,
      contentBuilder: (sheetContext) {
        if (stations.isEmpty) {
          return const AppStateView(
            title: 'No active broadcasts',
            description: 'Start a broadcast on your network to see it here.',
            icon: LucideIcons.radio,
          );
        }
        return Column(
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
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ChangeNotifierProvider.value(
      value: _vm,
      child: AppScaffold(
        body: MouseRegion(
          onHover: (_) => _vm.wakeOSD(),
          child: FocusScope(
            node: _osdFocusScope,
            onKeyEvent: _onKey,
            child: RepaintBoundary(
              key: _repaintKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Selector<PlayerViewModel, MediaItem?>(
                    selector: (_, vm) => vm.current,
                    builder: (context, item, _) =>
                        _buildMediaLayer(context, item),
                  ),
                  Selector<PlayerViewModel, (double, String)>(
                    selector: (_, vm) => (vm.gestureOpacity, vm.gestureTxt),
                    builder: (context, data, _) =>
                        _buildGestureFeedback(context, data.$1, data.$2),
                  ),
                  Selector<PlayerViewModel, bool>(
                    selector: (_, vm) => vm.showOSD,
                    builder: (context, show, _) => _buildOSD(context, show),
                  ),
                  Selector<PlayerViewModel, String?>(
                    selector: (_, vm) => vm.intercomMessage,
                    builder: (context, msg, _) =>
                        _buildIntercomOverlay(context, msg),
                  ),
                  Selector<PlayerViewModel, bool>(
                    selector: (_, vm) => vm.isLowFiMode,
                    builder: (context, lowFi, _) => lowFi
                        ? const LowFiIndicator(isTV: true)
                        : const SizedBox.shrink(),
                  ),
                  if (_showSidebar)
                    GestureDetector(
                      onTap: () => _toggleSidebar(false),
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
                        isTV: true,
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
    );
  }

  // ── Media Layers ──────────────────────────────────────────────────────────

  Widget _buildMediaLayer(BuildContext context, MediaItem? item) {
    final tokens = context.tokens;
    if (item == null) {
      return Center(child: CircularProgressIndicator(color: tokens.accent));
    }

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final coverSize = (screenWidth * 0.18).clamp(280.0, 480.0);
    return Container(
      color: tokens.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: coverSize,
              height: coverSize,
              decoration: BoxDecoration(
                color: tokens.surface1,
                borderRadius: BorderRadius.circular(DS.radius(24)),
                border: Border.all(
                  color: tokens.border.withValues(alpha: 0.65),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tokens.accent.withValues(alpha: 0.1),
                    offset: const Offset(12, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DS.radius(23)),
                child: NetworkImageFade(
                  url: _vm.thumbUrl,
                  fit: BoxFit.cover,
                  fallbackIcon: LucideIcons.music,
                ),
              ),
            ),
            SizedBox(height: (screenWidth * 0.025).clamp(24.0, 56.0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                item.title,
                style: AppTextStyles.style(
                  fontSize: (screenWidth * 0.025).clamp(28.0, 48.0),
                  fontWeight: AppTextStyles.titleFontWeight,
                  letterSpacing: -0.5,
                  color: tokens.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Audio stream',
              style: AppTextStyles.bodyLarge.copyWith(color: tokens.textMuted),
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
            border: Border.all(
              color: tokens.border.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Image.network(
            _vm.mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) =>
                Icon(LucideIcons.image, color: tokens.textMuted, size: 100),
          ),
        ),
      ),
    );
  }

  // ── OSD (VLC Inspired) ────────────────────────────────────────────────────

  Widget _buildOSD(BuildContext context, bool showOSD) {
    final tokens = context.tokens;
    return IgnorePointer(
      ignoring: !showOSD,
      child: AnimatedOpacity(
        opacity: showOSD ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: ExcludeFocus(
          excluding: !showOSD,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  tokens.background.withValues(alpha: 0.9),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_buildVlcBottomControls(context)],
            ),
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
          final nextItem = idx + 1 < total ? _vm.playlist[idx + 1] : null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Progress Bar
              if (item?.isImage == false) ...[
                PlayerProgressBar(
                  player: _vm.player,
                  compact: false,
                  isReadOnly: isBroadcast,
                ),
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
                            Flexible(
                              child: Text(
                                '${AppStrings.appTitle} · ${idx + 1} of $total',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.style(
                                  fontSize: (size.width * 0.008).clamp(
                                    12.0,
                                    16.0,
                                  ),
                                  color: tokens.textMuted,
                                ),
                              ),
                            ),
                            if (isBroadcast) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.error,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  AppStrings.live,
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: tokens.background,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item?.title ?? '',
                          style: AppTextStyles.style(
                            fontSize: (size.width * 0.012).clamp(18.0, 30.0),
                            fontWeight: AppTextStyles.titleFontWeight,
                            letterSpacing: -0.4,
                            color: tokens.textPrimary,
                          ).copyWith(height: 1.1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: MediaDetailsText(item: item),
                          ),
                        if (nextItem != null)
                          Semantics(
                            button: true,
                            label: '${AppStrings.upNext}: ${nextItem.title}',
                            child: InkWell(
                              onTap: _vm.next,
                              borderRadius: BorderRadius.circular(DS.radius(8)),
                              child: SizedBox(
                                height: 44,
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
                  // Playback Controls (Center)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerActionButton(
                        icon: LucideIcons.skipBack,
                        label: 'Previous item',
                        size: (size.width * 0.03).clamp(32.0, 48.0),
                        isTV: true,
                        onPressed: _vm.prev,
                      ),
                      const SizedBox(width: 16),
                      _buildPlayPauseBtn(context),
                      const SizedBox(width: 16),
                      PlayerActionButton(
                        icon: LucideIcons.skipForward,
                        label: 'Next item',
                        size: (size.width * 0.03).clamp(32.0, 48.0),
                        isTV: true,
                        onPressed: _vm.next,
                      ),
                    ],
                  ),
                  // Options (Right)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerActionButton(
                        icon: LucideIcons.settings2,
                        label: 'Player options',
                        size: (size.width * 0.025).clamp(28.0, 44.0),
                        isTV: true,
                        onPressed: () => _toggleSidebar(true),
                      ),
                      const SizedBox(width: 12),
                      PlayerActionButton(
                        icon: LucideIcons.x,
                        label: 'Close player',
                        size: (size.width * 0.025).clamp(28.0, 44.0),
                        isTV: true,
                        onPressed: () => context.pop(),
                        isDestructive: true,
                      ),
                    ],
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
        return PlayerActionButton(
          icon: playing ? LucideIcons.pause : LucideIcons.play,
          label: playing ? 'Pause' : 'Play',
          size: (size.width * 0.04).clamp(44.0, 64.0),
          isTV: true,
          isPrimary: true,
          focusNode: _playPauseFocusNode,
          onPressed: () {
            _vm
              ..togglePlayback()
              ..wakeOSD();
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
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(DS.radius(24)),
          ),
          border: Border(
            left: BorderSide(color: tokens.border.withValues(alpha: 0.7)),
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.background,
              blurRadius: 40,
              offset: const Offset(-20, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
                    size: (size.width * 0.02).clamp(20.0, 28.0),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Options',
                    style: AppTextStyles.style(
                      fontSize: (size.width * 0.015).clamp(20.0, 28.0),
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
                  _TVSidebarItem(
                    label: 'Station list',
                    icon: LucideIcons.radio,
                    focusNode: _sidebarFirstItemFocusNode,
                    onTap: _showStationModal,
                  ),
                  _TVSidebarItem(
                    label: 'Subtitle tracks',
                    icon: LucideIcons.subtitles,
                    onTap: () => _showTrackModal('subtitles'),
                  ),
                  _TVSidebarItem(
                    label: 'Audio tracks',
                    icon: LucideIcons.activity,
                    onTap: () => _showTrackModal('audio'),
                  ),
                  if (!(_vm.current?.isBroadcast ?? false))
                    _TVSidebarItem(
                      label: 'Playback speed',
                      icon: LucideIcons.gauge,
                      onTap: _showSpeedModal,
                    ),
                  _TVSidebarItem(
                    label: 'Aspect ratio',
                    icon: LucideIcons.minimize,
                    onTap: _showFitModal,
                  ),
                  _TVSidebarItem(
                    label: 'Sleep timer',
                    icon: LucideIcons.clock,
                    onTap: _showSleepModal,
                  ),
                  _TVSidebarItem(
                    label: 'Sync adjustment',
                    icon: LucideIcons.layers,
                    onTap: _showSyncModal,
                  ),
                ],
              ),
            ),
            _TVSidebarItem(
              label: 'Close',
              icon: LucideIcons.chevronRight,
              isDestructive: true,
              onTap: () => setState(() => _showSidebar = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureFeedback(
    BuildContext context,
    double opacity,
    String text,
  ) {
    final tokens = context.tokens;
    return Center(
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          decoration: BoxDecoration(
            color: tokens.textPrimary,
            borderRadius: BorderRadius.circular(DS.radius(24)),
          ),
          child: Text(
            text,
            style: AppTextStyles.sectionTitle.copyWith(
              color: tokens.background,
              fontWeight: AppTextStyles.titleFontWeight,
              letterSpacing: 0.8,
            ),
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
            borderRadius: BorderRadius.circular(DS.radius(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Priority broadcast',
                style: AppTextStyles.title.copyWith(
                  color: tokens.background,
                  fontWeight: AppTextStyles.titleFontWeight,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                msg,
                style: AppTextStyles.style(
                  color: tokens.background,
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
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

  void _showTrackModal(String type) {
    final tracks = type == 'audio'
        ? _vm.player.state.tracks.audio
        : _vm.player.state.tracks.subtitle;
    final current = type == 'audio'
        ? _vm.player.state.track.audio
        : _vm.player.state.track.subtitle;

    showPlayerOptionsSheet<void>(
      context: context,
      isTV: true,
      title: type == 'audio' ? 'Audio tracks' : 'Subtitles',
      subtitle: type == 'audio'
          ? 'Choose the audio track for this media.'
          : 'Choose a subtitle track or turn subtitles off.',
      icon: type == 'audio' ? LucideIcons.audioLines : LucideIcons.subtitles,
      maxWidth: 560,
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
                isTV: true,
                label: 'Disabled',
                isActive: current.id == 'no',
                onTap: () {
                  _vm.setSubtitleTrack(SubtitleTrack.no());
                  Navigator.pop(sheetContext);
                },
              ),
            for (final track in tracks)
              PlayerTrackTile(
                isTV: true,
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

  void _showSpeedModal() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final current = _vm.player.state.rate;

    showPlayerOptionsSheet<void>(
      context: context,
      isTV: true,
      title: 'Playback speed',
      subtitle: 'Adjust the playback rate.',
      icon: LucideIcons.gauge,
      maxWidth: 480,
      contentBuilder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final speed in speeds)
            PlayerTrackTile(
              isTV: true,
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

  void _showFitModal() {
    final fits = {
      BoxFit.contain: 'Contain',
      BoxFit.cover: 'Cover',
      BoxFit.fill: 'Stretch',
    };
    showPlayerOptionsSheet<void>(
      context: context,
      isTV: true,
      title: 'Aspect ratio',
      subtitle: 'Choose how the picture fits the screen.',
      icon: LucideIcons.scan,
      maxWidth: 480,
      contentBuilder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final fit in fits.entries)
            PlayerTrackTile(
              isTV: true,
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

  void _showSleepModal() {
    final options = [0, 5, 15, 30, 60, 120];
    showPlayerOptionsSheet<void>(
      context: context,
      isTV: true,
      title: 'Sleep timer',
      subtitle: 'Stop playback after a set time.',
      icon: LucideIcons.clock,
      maxWidth: 480,
      contentBuilder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final minutes in options)
            PlayerTrackTile(
              isTV: true,
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

  void _showSyncModal() {
    showPlayerOptionsSheet<void>(
      context: context,
      isTV: true,
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
              isTV: true,
              label: 'Audio offset',
              value: _vm.audioDelay,
              onChanged: _vm.setAudioDelay,
            ),
            PlayerSyncTile(
              isTV: true,
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

class _TVSidebarItem extends StatefulWidget {
  const _TVSidebarItem({
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: _focused ? tokens.surface3 : Colors.transparent,
              borderRadius: BorderRadius.circular(DS.radius(16)),
              border: Border.all(
                color: _focused
                    ? tokens.focusColor
                    : tokens.border.withValues(alpha: 0.55),
                width: _focused ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: _focused
                      ? tokens.error
                      : (widget.isDestructive
                            ? tokens.error
                            : tokens.textPrimary),
                  size: 24,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    widget.label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                      color: widget.isDestructive
                          ? tokens.error
                          : tokens.textPrimary,
                      letterSpacing: 0.5,
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
