// presentation/player/player_screen.dart
// ============================================================================
// STREAMZ — Universal Media Player Screen (Brutalist Web Studio Edition)
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

// --- Web UI Color Palette & Styles ---
const Color kWebBlack = Color(0xFF000000);
const Color kWebSurface = Color(0xFF0A0A0A);
const Color kWebSurface2 = Color(0xFF111111);
const Color kWebWhite = Color(0xFFFFFFFF);
final Color kWebBorder = Colors.white.withValues(alpha: 0.15);
final Color kWebTextMuted = Colors.white.withValues(alpha: 0.3);
final Color kWebText = Colors.white.withValues(alpha: 0.6);

const ColorFilter kGreyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      1, 0,
]);

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

    // 2. Hardware Media Keys
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

    // 3. OSD Hidden State
    if (!_vm.showOSD) {
      _vm.wakeOSD();

      if (item?.isVideo == true) {
        if (key == LogicalKeyboardKey.arrowRight) {
          _vm.seekRelative(const Duration(seconds: 10));
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          _vm.seekRelative(const Duration(seconds: -10));
          return KeyEventResult.handled;
        }
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
      return KeyEventResult.handled;
    }

    // 4. OSD Visible State
    _vm.wakeOSD();
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
        backgroundColor: kWebBlack,
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
                _vm.adjustVolume(delta); // Simulating brightness via volume for demo
              } else {
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
                    child: Container(color: kWebBlack.withValues(alpha: 0.6)),
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
        color: kWebBlack,
        child: Center(
          child: Image.network(
            _vm.mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(LucideIcons.image, color: kWebTextMuted, size: 64),
          ),
        ),
      );
    }

    if (item.isAudio) {
      return LayoutBuilder(
        builder: (_, c) {
          final sz = (c.maxHeight * 0.4).clamp(180.0, 500.0);
          return Container(
            color: kWebBlack,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: c.maxHeight * 0.15),
                child: Container(
                  width: sz,
                  height: sz,
                  decoration: BoxDecoration(
                    color: kWebSurface,
                    border: Border.all(color: kWebWhite, width: 2), // Brutalist sharp border
                  ),
                  child: ColorFiltered(
                    colorFilter: kGreyscale, // Brutalist industrial styling
                    child: NetworkImageFade(url: _vm.thumbUrl, fit: BoxFit.cover, fallbackIcon: LucideIcons.music),
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
      color: kWebBlack,
      child: Video(controller: _vm.videoController, controls: NoVideoControls, fit: _vm.videoFit),
    );
  }

  // ── Gesture feedback ──────────────────────────────────────────────────────

  Widget _buildGestureFeedback() => Center(
    child: AnimatedOpacity(
      opacity: _vm.gestureOpacity,
      duration: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: kWebSurface.withValues(alpha: 0.9),
          border: Border.all(color: kWebBorder, width: 1),
        ),
        child: Text(
          _vm.gestureTxt,
          style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ),
    ),
  );

  // ── OSD ───────────────────────────────────────────────────────────────────

  Widget _buildOSD() => AnimatedOpacity(
    opacity: _vm.showOSD ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 150),
    child: ExcludeFocus(
      excluding: !_vm.showOSD,
      child: IgnorePointer(
        ignoring: !_vm.showOSD,
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildTopBar(), const Spacer(), _buildBottomBar()]),
      ),
    ),
  );

  Widget _buildTopBar() {
    final item = _vm.current;
    return Container(
      // Minimal safe area padding to keep it extremely compact
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 12, 24, 12),
      decoration: BoxDecoration(
        color: kWebSurface.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: kWebBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BrutalistPlayerBtn(icon: LucideIcons.x, size: 20, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              (item?.title ?? '').toUpperCase(),
              style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 24, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'CMD // ${_vm.currentIndex + 1}/${_vm.playlist.length}',
            style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 12, letterSpacing: 2),
          ),
          const SizedBox(width: 16),
          BrutalistPlayerBtn(
            icon: LucideIcons.settings2,
            size: 20,
            onTap: () => setState(() => _showSidebar = true),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final item = _vm.current;
    return Container(
      // Squeezed padding against the bottom safe area
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.paddingOf(context).bottom + 12),
      decoration: BoxDecoration(
        color: kWebSurface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: kWebBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item?.isImage == false) ...[
            BrutalistProgressBar(player: _vm.player, compact: true), // Forced compact
            const SizedBox(height: 12)
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: _buildZone1(item, 20)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrutalistPlayerBtn(icon: LucideIcons.skipBack, size: 24, onTap: _vm.prev),
                  const SizedBox(width: 20),
                  _buildCenterBtn(item, 28), // Slightly smaller main button
                  const SizedBox(width: 20),
                  BrutalistPlayerBtn(icon: LucideIcons.skipForward, size: 24, onTap: _vm.next),
                ],
              ),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: _buildZone3(item, 20)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZone1(MediaItem? item, double sz) {
    if (item?.isVideo == true) {
      return BrutalistPlayerBtn(icon: LucideIcons.rewind, size: sz, onTap: () => _vm.seekRelative(const Duration(seconds: -10)));
    }
    if (item?.isImage == true) {
      return Text(
        'FILE ${_vm.currentIndex + 1} OF ${_vm.playlist.length}',
        style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1),
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

  // ── Tools Sidebar (Compact Brutalist) ─────────────────────────────────────

  Widget _buildToolsSidebar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      right: _showSidebar ? 0 : -240,
      top: 0,
      bottom: 0,
      width: 240,
      child: Container(
        decoration: BoxDecoration(
          color: kWebSurface,
          border: Border(left: BorderSide(color: kWebBorder)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
              child: Row(
                children: [
                  const Icon(LucideIcons.settings2, color: kWebWhite, size: 16),
                  const SizedBox(width: 12),
                  Text('SYS TOOLS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const Spacer(),
                  BrutalistPlayerBtn(icon: LucideIcons.x, size: 16, onTap: () => setState(() => _showSidebar = false)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
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

  // ── Modals (Compact Brutalist) ────────────────────────────────────────────

  void _showTrackModal(String type) {
    final tracks = type == 'audio' ? _vm.player.state.tracks.audio : _vm.player.state.tracks.subtitle;
    final current = type == 'audio' ? _vm.player.state.track.audio : _vm.player.state.track.subtitle;

    showGeneralDialog(
      context: context,
      barrierColor: kWebBlack.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: kWebSurface,
              border: Border.all(color: kWebWhite, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('${type.toUpperCase()} TRACKS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
      barrierColor: kWebBlack.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: kWebSurface,
              border: Border.all(color: kWebWhite, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('PLAYBACK SPEED', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
      barrierColor: kWebBlack.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: kWebSurface,
              border: Border.all(color: kWebWhite, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('VIDEO FIT', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
      barrierColor: kWebBlack.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: kWebSurface,
              border: Border.all(color: kWebWhite, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('SLEEP TIMER', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  void _showSyncModal() {
    showGeneralDialog(
      context: context,
      barrierColor: kWebBlack.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: kWebSurface,
              border: Border.all(color: kWebWhite, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('SYNC DELAY', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kWebBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              BrutalistPlayerBtn(icon: LucideIcons.minus, size: 16, onTap: () => onChanged(value - 0.1)),
              Expanded(
                child: Center(child: Text('${value.toStringAsFixed(1)}S', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 16, fontWeight: FontWeight.bold))),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _focused ? kWebWhite : Colors.transparent,
            border: Border(bottom: BorderSide(color: kWebBorder)),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: _focused ? kWebBlack : kWebTextMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.dmMono(
                    fontSize: 12,
                    fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                    color: _focused ? kWebBlack : kWebText,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 14, color: _focused ? kWebBlack : kWebTextMuted),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _focused ? kWebWhite : (widget.isActive ? kWebWhite.withValues(alpha:0.05) : Colors.transparent),
            border: Border(bottom: BorderSide(color: kWebBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.dmMono(
                    fontSize: 12,
                    fontWeight: _focused || widget.isActive ? FontWeight.bold : FontWeight.normal,
                    color: _focused ? kWebBlack : (widget.isActive ? kWebWhite : kWebText),
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (widget.isActive) Icon(LucideIcons.check, size: 16, color: _focused ? kWebBlack : kWebWhite),
            ],
          ),
        ),
      ),
    );
  }
}