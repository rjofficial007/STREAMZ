// presentation/tv/tv_player_screen.dart
// ============================================================================
// STREAMZ — TV Dedicated Media Player (VLC-Inspired Brutalist Edition)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/media_item.dart';
import '../client/client_viewmodel.dart';
import '../player/player_viewmodel.dart';

// --- TV UI Color Palette & Styles ---
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

class TVPlayerScreen extends StatefulWidget {
  final List<MediaItem> items;
  final int startIndex;
  final bool isPathBased;
  final Duration? startOffset;
  final bool autoPlay;

  const TVPlayerScreen({
    super.key,
    required this.items,
    required this.startIndex,
    this.isPathBased = false,
    this.startOffset,
    this.autoPlay = true,
  });

  @override
  State<TVPlayerScreen> createState() => _TVPlayerScreenState();
}

class _TVPlayerScreenState extends State<TVPlayerScreen> {
  late final PlayerViewModel _vm;
  final FocusScopeNode _osdFocusScope = FocusScopeNode();
  final FocusNode _playPauseFocusNode = FocusNode();

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
      _playPauseFocusNode.requestFocus();
    });
    _wasOSDVisible = _vm.showOSD;
    _vm.addListener(_onVMChange);
  }

  void _onVMChange() {
    if (mounted) {
      if (_vm.isStopped) {
        Navigator.pop(context);
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
    _vm.removeListener(_onVMChange);
    _vm.dispose();
    _osdFocusScope.dispose();
    _playPauseFocusNode.dispose();
    super.dispose();
  }

  // ── Key Handling (VLC Style) ──────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final item = _vm.current;

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.browserBack || key == LogicalKeyboardKey.goBack) {
      if (_showSidebar) {
        setState(() => _showSidebar = false);
        return KeyEventResult.handled;
      }
      if (_vm.showOSD) {
        _vm.hideOSD();
        return KeyEventResult.handled;
      }
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    if (!_vm.showOSD) {
      _vm.wakeOSD();
      if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        _vm.player.playOrPause();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
        return KeyEventResult.handled;
      }

      // Channel Switching
      if (key == LogicalKeyboardKey.channelUp) {
        _cycleStation(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.channelDown) {
        _cycleStation(-1);
        return KeyEventResult.handled;
      }

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

    _vm.wakeOSD();
    return KeyEventResult.ignored;
  }

  // ── Station Switching ─────────────────────────────────────────────────────

  void _cycleStation(int delta) {
    final clientVM = context.read<ClientViewModel>();
    final stations = clientVM.stations;
    if (stations.isEmpty) return;

    final currentStationId = _vm.current?.folder; // Using folder as station ID for broadcasts
    int idx = stations.indexWhere((s) => s['id'] == currentStationId);
    
    if (idx == -1) {
      idx = 0;
    } else {
      idx = (idx + delta) % stations.length;
    }
    _switchStation(stations[idx]);
  }

  void _switchStation(Map<String, dynamic> station) async {
    final clientVM = context.read<ClientViewModel>();
    final res = await clientVM.joinStation(station['id']);
    if (res != null && mounted) {
      final items = (res['playlist'] as List?)?.map((e) => MediaItem.fromJson(e)).toList() ?? [MediaItem.fromJson(res['item'])];
      final startIndex = res['itemIndex'] as int? ?? 0;
      final offsetMs = res['positionMs'] as int;
      final isPaused = res['isPaused'] as bool? ?? false;

      _vm.load(
        items: items,
        startIndex: startIndex,
        isPathBased: false,
        startOffset: Duration(milliseconds: offsetMs),
        autoPlay: !isPaused,
      );
    }
  }

  void _showStationModal() {
    final clientVM = context.read<ClientViewModel>();
    final stations = clientVM.stations;

    showGeneralDialog(
      context: context,
      barrierColor: kWebBlack.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 540,
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('LIVE BROADCAST STATIONS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                if (stations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text('NO ACTIVE BROADCASTS FOUND', style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 16, letterSpacing: 2), textAlign: TextAlign.center),
                  ),
                ...stations.map((s) => _TVTrackTile(
                  label: s['name'].toString().toUpperCase(),
                  isActive: _vm.current?.folder == s['id'],
                  onTap: () {
                    _switchStation(s);
                    Navigator.pop(ctx);
                  },
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: kWebBlack,
        body: MouseRegion(
          onHover: (_) => _vm.wakeOSD(),
          child: FocusScope(
            node: _osdFocusScope,
            onKeyEvent: _onKey,
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

  // ── Media Layers ──────────────────────────────────────────────────────────

  Widget _buildMediaLayer() {
    final item = _vm.current;
    if (item == null) return const Center(child: CircularProgressIndicator(color: kWebWhite));

    if (item.isImage) return _buildImageLayout(item);
    if (item.isAudio) return _buildAudioLayout(item);
    return _buildVideoLayout(item);
  }

  Widget _buildVideoLayout(MediaItem item) {
    return Container(
      color: kWebBlack,
      child: Video(
        controller: _vm.videoController,
        controls: NoVideoControls,
        fit: _vm.videoFit,
      ),
    );
  }

  Widget _buildAudioLayout(MediaItem item) {
    return Container(
      color: kWebBlack,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                color: kWebSurface,
                border: Border.all(color: kWebWhite, width: 2),
                boxShadow: [
                  BoxShadow(color: kWebWhite.withValues(alpha: 0.1), offset: const Offset(12, 12)),
                ],
              ),
              child: ColorFiltered(
                colorFilter: kGreyscale,
                child: NetworkImageFade(
                  url: _vm.thumbUrl,
                  fit: BoxFit.cover,
                  fallbackIcon: LucideIcons.music,
                ),
              ),
            ),
            const SizedBox(height: 60),
            Text(
              item.title.toUpperCase(),
              style: GoogleFonts.barlowCondensed(
                color: kWebWhite,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'SIGNAL_TYPE // AUDIO_STREAM',
              style: GoogleFonts.dmMono(
                color: kWebTextMuted,
                fontSize: 14,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageLayout(MediaItem item) {
    return Container(
      color: kWebBlack,
      padding: const EdgeInsets.all(60),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: kWebBorder, width: 1),
          ),
          child: Image.network(
            _vm.mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => Icon(LucideIcons.image, color: kWebTextMuted, size: 100),
          ),
        ),
      ),
    );
  }

  // ── OSD (VLC Inspired) ────────────────────────────────────────────────────

  Widget _buildOSD() => AnimatedOpacity(
    opacity: _vm.showOSD ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 250),
    child: ExcludeFocus(
      excluding: !_vm.showOSD,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [kWebBlack.withValues(alpha: 0.9), Colors.transparent],
            stops: const [0.0, 0.4],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildVlcBottomControls(),
          ],
        ),
      ),
    ),
  );

  Widget _buildVlcBottomControls() {
    final item = _vm.current;
    final isBroadcast = item?.isBroadcast ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Progress Bar
          if (item?.isImage == false) ...[
            BrutalistProgressBar(player: _vm.player, compact: false, isReadOnly: isBroadcast),
            const SizedBox(height: 24),
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
                          'STREAMZ // ${_vm.currentIndex + 1} OF ${_vm.playlist.length}',
                          style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 12, letterSpacing: 3),
                        ),
                        if (isBroadcast) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            color: Colors.redAccent,
                            child: Text(
                              'LIVE',
                              style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (item?.title ?? '').toUpperCase(),
                      style: GoogleFonts.barlowCondensed(
                        color: kWebWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        height: 1.1,
                      ),
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
                  _TVVlcBtn(icon: LucideIcons.skipBack, size: 48, onTap: _vm.prev),
                  const SizedBox(width: 16),
                  _buildPlayPauseBtn(),
                  const SizedBox(width: 16),
                  _TVVlcBtn(icon: LucideIcons.skipForward, size: 48, onTap: _vm.next),
                ],
              ),
              // Options (Right)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _TVVlcBtn(icon: LucideIcons.subtitles, size: 44, onTap: () => _showTrackModal('subtitles')),
                    const SizedBox(width: 12),
                    _TVVlcBtn(icon: LucideIcons.activity, size: 44, onTap: () => _showTrackModal('audio')),
                    const SizedBox(width: 12),
                    _TVVlcBtn(icon: LucideIcons.settings2, size: 44, onTap: () => setState(() => _showSidebar = true)),
                    const SizedBox(width: 12),
                    _TVVlcBtn(icon: LucideIcons.x, size: 44, onTap: () => Navigator.pop(context), isDestructive: true),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseBtn() {
    final item = _vm.current;
    if (item?.isImage == true) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: _vm.player.stream.playing,
      builder: (_, snap) {
        final playing = snap.data ?? false;
        return _TVVlcBtn(
          icon: playing ? LucideIcons.pause : LucideIcons.play,
          size: 64,
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

  Widget _buildToolsSidebar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      right: _showSidebar ? 0 : -420,
      top: 0,
      bottom: 0,
      width: 420,
      child: Container(
        decoration: BoxDecoration(
          color: kWebSurface,
          border: Border(left: BorderSide(color: kWebWhite, width: 2)),
          boxShadow: [
            BoxShadow(color: kWebBlack, blurRadius: 40, offset: const Offset(-20, 0)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
              child: Row(
                children: [
                  const Icon(LucideIcons.settings2, color: kWebWhite, size: 28),
                  const SizedBox(width: 20),
                  Text('SYSTEM_CONFIG', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _TVSidebarItem(label: 'STATION LIST', icon: LucideIcons.radio, onTap: _showStationModal),
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

  Widget _buildGestureFeedback() {
    return Center(
      child: AnimatedOpacity(
        opacity: _vm.gestureOpacity,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          decoration: BoxDecoration(
            color: kWebWhite,
            border: Border.all(color: kWebBlack, width: 4),
          ),
          child: Text(
            _vm.gestureTxt.toUpperCase(),
            style: GoogleFonts.dmMono(color: kWebBlack, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
        ),
      ),
    );
  }

  // ── Modals ────────────────────────────────────────────────────────────────

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
            width: 540,
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('${type.toUpperCase()} SIGNAL SELECT', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                if (type == 'subtitles')
                  _TVTrackTile(label: 'DISABLE SUBTITLES', isActive: current.id == 'no', onTap: () { _vm.setSubtitleTrack(SubtitleTrack.no()); Navigator.pop(ctx); }),
                ...tracks.map((t) => _TVTrackTile(
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
            width: 440,
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('PLAYBACK RATE', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                ...speeds.map((s) => _TVTrackTile(
                  label: '${s}X SPEED',
                  isActive: (s - current).abs() < 0.01,
                  onTap: () { _vm.setRate(s); Navigator.pop(ctx); },
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFitModal() {
    final fits = {BoxFit.contain: 'CONTAIN', BoxFit.cover: 'FILL_COVER', BoxFit.fill: 'STRETCH_FILL'};
    showGeneralDialog(
      context: context,
      barrierColor: kWebBlack.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 440,
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('ASPECT_CALIBRATION', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                ...fits.entries.map((e) => _TVTrackTile(
                  label: e.value,
                  isActive: _vm.videoFit == e.key,
                  onTap: () { _vm.setVideoFit(e.key); Navigator.pop(ctx); },
                )),
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
            width: 440,
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('AUTO_SHUTDOWN', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                ...options.map((m) => _TVTrackTile(
                  label: m == 0 ? 'DISABLED' : '$m MINUTES',
                  isActive: _vm.sleepMinutesRemaining == m,
                  onTap: () { _vm.setSleepTimer(m); Navigator.pop(ctx); },
                )),
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
            width: 440,
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('SYNC_ADJUSTMENT', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                ListenableBuilder(
                  listenable: _vm,
                  builder: (_, child) => Column(
                    children: [
                      _TVSyncTile(label: 'AUDIO OFFSET', value: _vm.audioDelay, onChanged: _vm.setAudioDelay),
                      _TVSyncTile(label: 'SUBTITLE OFFSET', value: _vm.subDelay, onChanged: _vm.setSubtitleDelay),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// VLC UI COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _TVVlcBtn extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool isDestructive;
  final FocusNode? focusNode;

  const _TVVlcBtn({required this.icon, required this.size, this.onTap, this.isPrimary = false, this.isDestructive = false, this.focusNode});

  @override
  State<_TVVlcBtn> createState() => _TVVlcBtnState();
}

class _TVVlcBtnState extends State<_TVVlcBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bg = _focused ? (widget.isDestructive ? Colors.redAccent : kWebWhite) : (widget.isPrimary ? kWebSurface2 : Colors.transparent);
    final fg = _focused ? kWebBlack : (widget.isDestructive ? Colors.redAccent : kWebWhite);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: _focused ? kWebWhite : kWebBorder, width: _focused ? 4 : 1),
          ),
          child: Icon(widget.icon, color: fg, size: widget.size * 0.5),
        ),
      ),
    );
  }
}

class _TVSidebarItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _TVSidebarItem({required this.label, required this.icon, required this.onTap, this.isDestructive = false});

  @override
  State<_TVSidebarItem> createState() => _TVSidebarItemState();
}

class _TVSidebarItemState extends State<_TVSidebarItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: _focused ? (widget.isDestructive ? Colors.redAccent : kWebWhite) : Colors.transparent,
            border: Border(bottom: BorderSide(color: kWebBorder)),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: _focused ? kWebBlack : (widget.isDestructive ? Colors.redAccent : kWebWhite), size: 24),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.dmMono(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _focused ? kWebBlack : (widget.isDestructive ? Colors.redAccent : kWebWhite),
                    letterSpacing: 2,
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

class _TVTrackTile extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TVTrackTile({required this.label, required this.isActive, required this.onTap});

  @override
  State<_TVTrackTile> createState() => _TVTrackTileState();
}

class _TVTrackTileState extends State<_TVTrackTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: _focused ? kWebWhite : (widget.isActive ? kWebWhite.withValues(alpha: 0.05) : Colors.transparent),
            border: Border(bottom: BorderSide(color: kWebBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.dmMono(
                    fontSize: 16,
                    fontWeight: _focused || widget.isActive ? FontWeight.bold : FontWeight.normal,
                    color: _focused ? kWebBlack : (widget.isActive ? kWebWhite : kWebText),
                    letterSpacing: 2,
                  ),
                ),
              ),
              if (widget.isActive) Icon(LucideIcons.check, color: _focused ? kWebBlack : kWebWhite, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TVSyncTile extends StatelessWidget {
  final String label;
  final double value;
  final Function(double) onChanged;

  const _TVSyncTile({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 14, letterSpacing: 2)),
          const SizedBox(height: 24),
          Row(
            children: [
              _TVVlcBtn(icon: LucideIcons.minus, size: 64, onTap: () => onChanged(value - 0.1)),
              Expanded(
                child: Center(
                  child: Text(
                    '${value.toStringAsFixed(1)}S',
                    style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _TVVlcBtn(icon: LucideIcons.plus, size: 64, onTap: () => onChanged(value + 0.1)),
            ],
          ),
        ],
      ),
    );
  }
}