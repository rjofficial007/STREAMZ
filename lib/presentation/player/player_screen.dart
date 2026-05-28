// presentation/player/player_screen.dart
// ============================================================================
// STREAMZ — Universal Media Player Screen (Cinematic UI & D-Pad Optimized)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/models/media_item.dart';
import 'player_viewmodel.dart';

class PlayerScreen extends StatefulWidget {
  final List<MediaItem> items;
  final int startIndex;
  final bool isPathBased;
  final Duration? startOffset;

  const PlayerScreen({super.key, required this.items, required this.startIndex, this.isPathBased = false, this.startOffset});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerViewModel _vm;

  final FocusScopeNode _osdFocusScope = FocusScopeNode();
  final FocusNode _primaryFocusNode = FocusNode();

  bool _wasOSDVisible = true;
  bool _showSidebar = false;

  bool get _isTV => MediaQuery.sizeOf(context).width >= DS.bpTV;

  @override
  void initState() {
    super.initState();
    _vm = PlayerViewModel();
    _vm.load(items: widget.items, startIndex: widget.startIndex, isPathBased: widget.isPathBased, startOffset: widget.startOffset).then((_) {
      _primaryFocusNode.requestFocus();
    });
    _wasOSDVisible = _vm.showOSD;
    _vm.addListener(_onVMChange);
  }

  void _onVMChange() {
    if (mounted) {
      // Auto-Refocus: If the OSD was asleep and just woke up, snap the user's TV
      // remote cursor back to the primary Play/Pause button so they aren't lost.
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
    _vm.removeListener(_onVMChange);
    _vm.dispose();
    _osdFocusScope.dispose();
    _primaryFocusNode.dispose();
    super.dispose();
  }

  // ── Key handling (D-Pad & Keyboard) ───────────────────────────────────────

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final item = _vm.current;

    // 1. Global Exits
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.browserBack || key == LogicalKeyboardKey.goBack) {
      if (_showSidebar) {
        setState(() => _showSidebar = false);
        return KeyEventResult.handled;
      }
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    // 2. Hardware Media Keys (Always work, regardless of OSD state)
    if (key == LogicalKeyboardKey.mediaPlayPause || key == LogicalKeyboardKey.space) {
      _vm.player.playOrPause();
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaFastForward) {
      _vm.seekRelative(const Duration(seconds: 10));
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaRewind) {
      _vm.seekRelative(const Duration(seconds: -10));
      _vm.wakeOSD();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      _vm.next();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      _vm.prev();
      return KeyEventResult.handled;
    }

    // 3. OSD Hidden State (D-Pad acts as quick media controls)
    if (!_vm.showOSD) {
      _vm.wakeOSD(); // Any key wakes the UI

      if (item?.isVideo == true) {
        if (key == LogicalKeyboardKey.arrowRight) {
          _vm.seekRelative(const Duration(seconds: 10));
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          _vm.seekRelative(const Duration(seconds: -10));
          return KeyEventResult.handled;
        }
        // PRO SKIP: Up/Down for large jumps (Kodi/VLC Style)
        if (key == LogicalKeyboardKey.arrowUp) {
          _vm.seekRelative(const Duration(minutes: 1));
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          _vm.seekRelative(const Duration(seconds: -30));
          return KeyEventResult.handled;
        }
      } else if (item?.isImage == true) {
        if (key == LogicalKeyboardKey.arrowRight) {
          _vm.next();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          _vm.prev();
          return KeyEventResult.handled;
        }
      }

      // If it was just "Enter" or "Up/Down", we just woke the OSD and do nothing else.
      return KeyEventResult.handled;
    }

    // 4. OSD Visible State (D-Pad acts as UI Navigation)
    _vm.wakeOSD(); // Reset hide timer on any navigation

    // We explicitly IGNORE arrow keys here so Flutter's Focus Engine takes over
    // and naturally moves the highlight box to the next on-screen button.
    return KeyEventResult.ignored;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final item = _vm.current;
    if (item?.isVideo == true) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: Colors.black, // True black background for media playback
        body: FocusScope(
          node: _osdFocusScope,
          onKeyEvent: _onKey,
          child: GestureDetector(
            onTap: () {
              _vm.toggleOSD();
            },
            onDoubleTapDown: (d) {
              final half = MediaQuery.sizeOf(context).width / 2;
              _vm.seekRelative(Duration(seconds: d.globalPosition.dx < half ? -10 : 10));
            },
            onHorizontalDragUpdate: (d) {
              final dur = _vm.player.state.duration.inSeconds;
              if (item?.isImage == true || dur <= 0) return;
              final factor = d.primaryDelta! / MediaQuery.sizeOf(context).width;
              final scrubSec = (factor * dur).toInt();
              if (scrubSec != 0) {
                _vm.player.seek(_vm.player.state.position + Duration(seconds: scrubSec));
              }
            },
            onVerticalDragUpdate: (d) {
              if (item?.isVideo != true) return;
              final half = MediaQuery.sizeOf(context).width / 2;
              final delta = -d.primaryDelta! / MediaQuery.sizeOf(context).height * 100;
              if (d.globalPosition.dx < half) {
                // Left side: Brightness (Simulator/Hardware dependent, using volume for demo if brightness unavailable)
                _vm.adjustVolume(delta);
              } else {
                // Right side: Volume
                _vm.adjustVolume(delta);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildMediaLayer(),
                _buildGestureFeedback(),
                _buildOSD(),
                if (_showSidebar)
                  GestureDetector(
                    onTap: () => setState(() => _showSidebar = false),
                    child: Container(color: Colors.black45),
                  ),
                _buildToolsSidebar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Media layer ───────────────────────────────────────────────────────────

  Widget _buildMediaLayer() {
    final item = _vm.current;
    if (item == null) return const SizedBox.shrink();

    if (item.isImage) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Image.network(
            _vm.mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(LucideIcons.image, color: Colors.white24, size: 64),
          ),
        ),
      );
    }

    if (item.isAudio) {
      return LayoutBuilder(
        builder: (_, c) {
          // Constrained size for audio art
          final sz = (c.maxHeight * 0.4).clamp(180.0, 500.0);
          return Container(
            color: Colors.black,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: c.maxHeight * 0.15),
                // Apply the Brutalist Effect here
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: sz,
                  height: sz,
                  decoration: BoxDecoration(
                    color: DS.surface1,
                    border: Border.all(
                      color: DS.borderDefault,
                      width: _isTV ? 3 : 2, // Slightly thicker for brutalist look
                    ),
                    boxShadow: [
                      // Signature Brutalist Offset Shadow
                      BoxShadow(
                        color: DS.accent,
                        offset: const Offset(8, 8),
                        blurRadius: 0, // Brutalist shadows are usually sharp
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Artwork
                      Positioned.fill(
                        child: NetworkImageFade(url: _vm.thumbUrl, fit: BoxFit.cover, fallbackIcon: LucideIcons.music),
                      ),
                      // Optional: Subtle overlay to pop the "Brutalist" border
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.white10, width: 1)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Video
    return Container(
      color: Colors.black,
      child: Video(controller: _vm.videoController, controls: NoVideoControls, fit: _vm.videoFit),
    );
  }

  // ── Gesture feedback ──────────────────────────────────────────────────────

  Widget _buildGestureFeedback() => Center(
    child: AnimatedOpacity(
      opacity: _vm.gestureOpacity,
      duration: const Duration(milliseconds: 150),
      child: LayoutBuilder(
        builder: (_, c) {
          final hPad = c.maxWidth * 0.04;
          final vPad = c.maxHeight * 0.025;
          final fs = (c.maxWidth * 0.022).clamp(12.0, 32.0); // Sleeker font size
          return Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              color: DS.surface1.withValues(alpha: 0.8), // Slightly transparent
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DS.borderDefault, width: 1),
            ),
            child: Text(
              _vm.gestureTxt,
              style: AppTheme.theme.textTheme.titleMedium?.copyWith(color: DS.accent, fontSize: fs),
            ),
          );
        },
      ),
    ),
  );

  // ── OSD ───────────────────────────────────────────────────────────────────

  Widget _buildOSD() => AnimatedOpacity(
    opacity: _vm.showOSD ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 300), // Smoother cinematic fade
    child: ExcludeFocus(
      excluding: !_vm.showOSD, // Drops Focusability entirely when OSD hides
      child: IgnorePointer(
        ignoring: !_vm.showOSD,
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildTopBar(), const Spacer(), _buildBottomBar()]),
      ),
    ),
  );

  Widget _buildToolsSidebar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      right: _showSidebar ? 0 : -350,
      top: 0,
      bottom: 0,
      width: 300,
      child: Container(
        decoration: BoxDecoration(
          color: DS.surface1.withValues(alpha: 0.95),
          border: const Border(left: BorderSide(color: DS.borderDefault)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(DS.s24),
              color: DS.surface2,
              child: Row(
                children: [
                  const Icon(LucideIcons.settings2, color: DS.accent, size: 20),
                  const SizedBox(width: 12),
                  Text('TOOLS', style: AppTheme.theme.textTheme.titleMedium),
                  const Spacer(),
                  BrutalistPlayerBtn(icon: LucideIcons.x, size: 16, onTap: () => setState(() => _showSidebar = false)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _VlcSidebarItem(icon: LucideIcons.subtitles, label: 'SUBTITLES', onTap: () => _showTrackModal('subtitles')),
                  _VlcSidebarItem(icon: LucideIcons.activity, label: 'AUDIO TRACK', onTap: () => _showTrackModal('audio')),
                  _VlcSidebarItem(icon: LucideIcons.layers, label: 'SYNC DELAY', onTap: _showSyncModal),
                  _VlcSidebarItem(icon: LucideIcons.gauge, label: 'PLAYBACK SPEED', onTap: _showSpeedModal),
                  _VlcSidebarItem(icon: LucideIcons.minimize, label: 'VIDEO FIT', onTap: _showFitModal),
                  _VlcSidebarItem(icon: LucideIcons.clock, label: _vm.sleepMinutesRemaining > 0 ? '${_vm.sleepMinutesRemaining}M REMAINING' : 'SLEEP TIMER', onTap: _showSleepModal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackModal(String type) {
    final tracks = type == 'audio' ? _vm.player.state.tracks.audio : _vm.player.state.tracks.subtitle;
    final current = type == 'audio' ? _vm.player.state.track.audio : _vm.player.state.track.subtitle;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: DS.surface1,
              border: Border.all(color: DS.borderDefault),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(DS.s24),
                  color: DS.surface2,
                  child: Text('${type.toUpperCase()} TRACKS', style: AppTheme.theme.textTheme.titleMedium),
                ),
                if (type == 'subtitles')
                  _TrackTile(
                    label: 'DISABLE SUBTITLES',
                    isActive: current.id == 'no',
                    onTap: () {
                      _vm.setSubtitleTrack(SubtitleTrack.no());
                      Navigator.pop(ctx);
                    },
                  ),
                ...tracks.map(
                  (t) => _TrackTile(
                    label: (t.title ?? t.language ?? t.id).toUpperCase(),
                    isActive: t.id == current.id,
                    onTap: () {
                      type == 'audio' ? _vm.setAudioTrack(t as AudioTrack) : _vm.setSubtitleTrack(t as SubtitleTrack);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSpeedModal() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final current = _vm.player.state.rate;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: DS.surface1,
              border: Border.all(color: DS.borderDefault),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(DS.s24),
                  color: DS.surface2,
                  child: Text('PLAYBACK SPEED', style: AppTheme.theme.textTheme.titleMedium),
                ),
                ...speeds.map(
                  (s) => _TrackTile(
                    label: '${s}X',
                    isActive: (s - current).abs() < 0.01,
                    onTap: () {
                      _vm.setRate(s);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFitModal() {
    final fits = {BoxFit.contain: 'FIT (CONTAIN)', BoxFit.cover: 'FILL (COVER)', BoxFit.fill: 'STRETCH (FILL)'};

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: DS.surface1,
              border: Border.all(color: DS.borderDefault),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(DS.s24),
                  color: DS.surface2,
                  child: Text('VIDEO FIT', style: AppTheme.theme.textTheme.titleMedium),
                ),
                ...fits.entries.map(
                  (e) => _TrackTile(
                    label: e.value,
                    isActive: _vm.videoFit == e.key,
                    onTap: () {
                      _vm.setVideoFit(e.key);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSleepModal() {
    final options = [0, 5, 15, 30, 60, 120];

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: DS.surface1,
              border: Border.all(color: DS.borderDefault),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(DS.s24),
                  color: DS.surface2,
                  child: Text('SLEEP TIMER', style: AppTheme.theme.textTheme.titleMedium),
                ),
                ...options.map(
                  (m) => _TrackTile(
                    label: m == 0 ? 'OFF' : '$m MINUTES',
                    isActive: _vm.sleepMinutesRemaining == m,
                    onTap: () {
                      _vm.setSleepTimer(m);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final item = _vm.current;
    return LayoutBuilder(
      builder: (_, c) {
        final hPad = (c.maxWidth * 0.03).clamp(24.0, 64.0);
        final vPad = MediaQuery.paddingOf(context).top + (c.maxHeight * 0.03).clamp(16.0, 48.0);
        final titleFs = (c.maxWidth * 0.025).clamp(16.0, 40.0); // Refined typography size
        final btnSz = (c.maxWidth * 0.02).clamp(16.0, 32.0);

        return Container(
          padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, (c.maxHeight * 0.05).clamp(20.0, 60.0)),
          decoration: BoxDecoration(
            // Replaced solid block with a sleek, cinematic transparent fade
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DS.bg.withValues(alpha: 0.85), Colors.transparent]),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BrutalistPlayerBtn(icon: LucideIcons.x, size: btnSz, onTap: () => Navigator.pop(context)),
              SizedBox(width: hPad * 0.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NOW PLAYING // ${_typeLabel(item)}',
                      style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.accent, fontSize: (c.maxWidth * 0.01).clamp(9.0, 14.0)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (item?.title ?? '').toUpperCase(),
                      style: AppTheme.theme.textTheme.displayMedium?.copyWith(fontSize: titleFs, height: 1.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '${_vm.currentIndex + 1}/${_vm.playlist.length}',
                style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: (c.maxWidth * 0.01).clamp(9.0, 16.0), color: Colors.white70),
              ),
              const SizedBox(width: 16),
              BrutalistPlayerBtn(
                icon: LucideIcons.ellipsisVertical,
                size: btnSz,
                onTap: () => setState(() => _showSidebar = true),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final item = _vm.current;
    return LayoutBuilder(
      builder: (_, c) {
        final hPad = (c.maxWidth * 0.03).clamp(24.0, 64.0);
        final vPad = MediaQuery.paddingOf(context).bottom + (c.maxHeight * 0.03).clamp(16.0, 48.0);

        // Re-clamped sizes: Much more elegant and less aggressive on massive displays
        final mainSz = (c.maxWidth * 0.03).clamp(24.0, 56.0);
        final skipSz = (c.maxWidth * 0.02).clamp(18.0, 36.0);
        final seekSz = (c.maxWidth * 0.015).clamp(16.0, 32.0);
        final gap = (c.maxWidth * 0.03).clamp(16.0, 48.0);

        return Container(
          padding: EdgeInsets.fromLTRB(hPad, (c.maxHeight * 0.05).clamp(20.0, 80.0), hPad, vPad),
          decoration: BoxDecoration(
            // Replaced solid block with a sleek, cinematic transparent fade
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [DS.bg.withValues(alpha: 0.95), Colors.transparent]),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item?.isImage == false) ...[BrutalistProgressBar(player: _vm.player, compact: !_isTV), SizedBox(height: gap)],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: _buildZone1(item, seekSz)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BrutalistPlayerBtn(icon: LucideIcons.skipBack, size: skipSz, onTap: _vm.prev),
                      SizedBox(width: gap),
                      _buildCenterBtn(item, mainSz),
                      SizedBox(width: gap),
                      BrutalistPlayerBtn(icon: LucideIcons.skipForward, size: skipSz, onTap: _vm.next),
                    ],
                  ),
                  Expanded(
                    child: Align(alignment: Alignment.centerRight, child: _buildZone3(item, seekSz)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZone1(MediaItem? item, double sz) {
    if (item?.isVideo == true) {
      return BrutalistPlayerBtn(icon: LucideIcons.rewind, size: sz, onTap: () => _vm.seekRelative(const Duration(seconds: -10)));
    }
    if (item?.isImage == true) {
      return Text(
        'FILE ${_vm.currentIndex + 1} OF ${_vm.playlist.length}',
        style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: _isTV ? 14 : 10, color: Colors.white70),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCenterBtn(MediaItem? item, double sz) {
    if (item?.isImage == true) {
      return BrutalistPlayerBtn(focusNode: _primaryFocusNode, autoFocus: true, isPrimary: true, icon: LucideIcons.squareDashedTopSolid, size: sz, onTap: () => Navigator.pop(context));
    }
    return StreamBuilder<bool>(
      stream: _vm.player.stream.playing,
      builder: (_, s) {
        final playing = s.data ?? false;
        return BrutalistPlayerBtn(
          focusNode: _primaryFocusNode,
          autoFocus: true,
          isPrimary: true,
          icon: playing ? LucideIcons.pause : LucideIcons.play,
          size: sz,
          onTap: () {
            _vm.player.playOrPause();
            _vm.wakeOSD();
          },
        );
      },
    );
  }

  Widget _buildZone3(MediaItem? item, double sz) {
    if (item?.isVideo == true) {
      return BrutalistPlayerBtn(icon: LucideIcons.fastForward, size: sz, onTap: () => _vm.seekRelative(const Duration(seconds: 10)));
    }
    if (item?.isAudio == true) {
      return BrutalistPlayerBtn(icon: LucideIcons.squareDashedTopSolid, size: sz, onTap: () => Navigator.pop(context));
    }
    return const SizedBox.shrink();
  }

  static const _typeLabels = {'video': 'VID', 'audio': 'AUD', 'image': 'IMG'};
  String _typeLabel(MediaItem? item) => _typeLabels[item?.type] ?? 'SYS';

  void _showSyncModal() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: DS.surface1,
              border: Border.all(color: DS.borderDefault),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(DS.s24),
                  color: DS.surface2,
                  child: Text('SYNC DELAY', style: AppTheme.theme.textTheme.titleMedium),
                ),
                ListenableBuilder(
                  listenable: _vm,
                  builder: (context, _) {
                    return Column(
                      children: [
                        _SyncTile(label: 'AUDIO DELAY', value: _vm.audioDelay, onChanged: (v) => _vm.setAudioDelay(v)),
                        _SyncTile(label: 'SUBTITLE DELAY', value: _vm.subDelay, onChanged: (v) => _vm.setSubtitleDelay(v)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncTile extends StatelessWidget {
  final String label;
  final double value;
  final Function(double) onChanged;

  const _SyncTile({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DS.borderDefault)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.theme.textTheme.labelSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              BrutalistPlayerBtn(icon: LucideIcons.minus, size: 16, onTap: () => onChanged(value - 0.1)),
              Expanded(
                child: Center(child: Text('${value.toStringAsFixed(1)}S', style: AppTheme.theme.textTheme.titleMedium)),
              ),
              BrutalistPlayerBtn(icon: LucideIcons.plus, size: 16, onTap: () => onChanged(value + 0.1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _VlcSidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _VlcSidebarItem({required this.icon, required this.label, required this.onTap});

  @override
  State<_VlcSidebarItem> createState() => _VlcSidebarItemState();
}

class _VlcSidebarItemState extends State<_VlcSidebarItem> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _focused ? DS.accent : DS.surface2,
            border: Border.all(color: _focused ? DS.accent : DS.borderDefault),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: _focused ? Colors.black : DS.textPrimary),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: _focused ? Colors.black : DS.textSecondary),
              ),
              const Spacer(),
              Icon(LucideIcons.chevronRight, size: 14, color: _focused ? Colors.black : Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackTile extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TrackTile({required this.label, required this.isActive, required this.onTap});

  @override
  State<_TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<_TrackTile> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _focused ? DS.accent : (widget.isActive ? DS.surface3 : Colors.transparent),
            border: Border(bottom: BorderSide(color: DS.borderDefault)),
          ),
          child: Row(
            children: [
              Text(widget.label, style: AppTheme.theme.textTheme.labelMedium?.copyWith(color: _focused ? Colors.black : Colors.white)),
              const Spacer(),
              if (widget.isActive) Icon(LucideIcons.checkCircle, size: 20, color: _focused ? Colors.black : DS.accent),
            ],
          ),
        ),
      ),
    );
  }
}
