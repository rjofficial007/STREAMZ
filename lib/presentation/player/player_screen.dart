// presentation/player/player_screen.dart
// ============================================================================
// STREAMZ — Universal Media Player Screen (VLC-Inspired Brutalist Edition)
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
import 'player_viewmodel.dart';

// --- UI Color Palette & Styles (Sync with TVPlayerScreen) ---
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
  final bool autoPlay;

  const PlayerScreen({
    super.key,
    required this.items,
    required this.startIndex,
    this.isPathBased = false,
    this.startOffset,
    this.autoPlay = true,
  });

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
    _vm.load(
      items: widget.items,
      startIndex: widget.startIndex,
      isPathBased: widget.isPathBased,
      startOffset: widget.startOffset,
      autoPlay: widget.autoPlay,
    ).then((_) {
      _primaryFocusNode.requestFocus();
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

  // ── Key handling (Keyboard & Remote) ──────────────────────────────────────

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

    // Universal Wake
    _vm.wakeOSD();

    if (!_vm.showOSD) {
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
    }

    return KeyEventResult.ignored;
  }

  // ── Station Switching ─────────────────────────────────────────────────────

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
            width: MediaQuery.sizeOf(context).width * 0.85,
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text('LIVE STATIONS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: stations.map((s) => _MobileTrackTile(
                      label: s['name'].toString().toUpperCase(),
                      isActive: _vm.current?.folder == s['id'],
                      onTap: () {
                        _switchStation(s);
                        Navigator.pop(ctx);
                      },
                    )).toList(),
                  ),
                ),
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
    return LayoutBuilder(builder: (context, constraints) {
      final isLandscape = constraints.maxWidth > constraints.maxHeight;
      final sz = (isLandscape ? constraints.maxHeight * 0.4 : constraints.maxWidth * 0.5).clamp(120.0, 300.0);

      return Container(
        color: kWebBlack,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: sz,
                height: sz,
                decoration: BoxDecoration(
                  color: kWebSurface,
                  border: Border.all(color: kWebWhite, width: 1),
                  boxShadow: [
                    BoxShadow(color: kWebWhite.withValues(alpha: 0.1), offset: const Offset(4, 4)),
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
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  item.title.toUpperCase(),
                  style: GoogleFonts.barlowCondensed(
                    color: kWebWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SIGNAL_TYPE // AUDIO_STREAM',
                style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 8, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildImageLayout(MediaItem item) {
    return Container(
      color: kWebBlack,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: kWebBorder, width: 1)),
          child: Image.network(
            _vm.mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => Icon(LucideIcons.image, color: kWebTextMuted, size: 64),
          ),
        ),
      ),
    );
  }

  // ── OSD (Mobile VLC Style) ────────────────────────────────────────────────

  Widget _buildOSD() => AnimatedOpacity(
    opacity: _vm.showOSD ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 250),
    child: ExcludeFocus(
      excluding: !_vm.showOSD,
      child: Stack(
        children: [
          _buildTopBar(),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildVlcBottomControls(),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildTopBar() {
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
            colors: [kWebBlack.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            _MobileIconBtn(icon: LucideIcons.chevronLeft, size: 32, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (item?.title ?? '').toUpperCase(),
                    style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'CMD // ${_vm.currentIndex + 1} OF ${_vm.playlist.length}',
                    style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 8, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            _MobileIconBtn(icon: LucideIcons.settings2, size: 32, onTap: () => setState(() => _showSidebar = true)),
          ],
        ),
      ),
    );
  }

  Widget _buildVlcBottomControls() {
    final item = _vm.current;
    final isBroadcast = item?.isBroadcast ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.paddingOf(context).bottom + 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [kWebBlack.withValues(alpha: 0.9), Colors.transparent],
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
              _MobileIconBtn(icon: LucideIcons.subtitles, size: 28, onTap: () => _showTrackModal('subtitles')),
              const SizedBox(width: 4),
              if (isBroadcast)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  color: Colors.redAccent,
                  child: Text('LIVE', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 8, fontWeight: FontWeight.bold)),
                ),

              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MobileIconBtn(icon: LucideIcons.skipBack, size: 28, onTap: _vm.prev),
                  const SizedBox(width: 16),
                  _buildPlayPauseBtn(),
                  const SizedBox(width: 16),
                  _MobileIconBtn(icon: LucideIcons.skipForward, size: 28, onTap: _vm.next),
                ],
              ),
              const Spacer(),

              _MobileIconBtn(icon: LucideIcons.activity, size: 28, onTap: () => _showTrackModal('audio')),
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

  Widget _buildToolsSidebar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      right: _showSidebar ? 0 : -220,
      top: 0,
      bottom: 0,
      width: 220,
      child: Container(
        decoration: BoxDecoration(
          color: kWebSurface,
          border: Border(left: BorderSide(color: kWebWhite, width: 1)),
          boxShadow: [BoxShadow(color: kWebBlack, blurRadius: 20)],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                child: Row(
                  children: [
                    const Icon(LucideIcons.settings2, color: kWebWhite, size: 16),
                    const SizedBox(width: 8),
                    Text('TOOLS', style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _MobileSidebarItem(label: 'STATION LIST', icon: LucideIcons.radio, onTap: _showStationModal),
                    _MobileSidebarItem(label: 'SUBTITLES', icon: LucideIcons.subtitles, onTap: () => _showTrackModal('subtitles')),
                    _MobileSidebarItem(label: 'AUDIO TRACKS', icon: LucideIcons.activity, onTap: () => _showTrackModal('audio')),
                    if (!(_vm.current?.isBroadcast ?? false))
                      _MobileSidebarItem(label: 'SPEED', icon: LucideIcons.gauge, onTap: _showSpeedModal),
                    _MobileSidebarItem(label: 'ASPECT', icon: LucideIcons.minimize, onTap: _showFitModal),
                    _MobileSidebarItem(label: 'SLEEP TIMER', icon: LucideIcons.clock, onTap: _showSleepModal),
                    _MobileSidebarItem(label: 'SYNC ADJUST', icon: LucideIcons.layers, onTap: _showSyncModal),
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

  Widget _buildGestureFeedback() {
    return Center(
      child: AnimatedOpacity(
        opacity: _vm.gestureOpacity,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: kWebWhite, border: Border.all(color: kWebBlack, width: 1)),
          child: Text(
            _vm.gestureTxt.toUpperCase(),
            style: GoogleFonts.dmMono(color: kWebBlack, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
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
            width: MediaQuery.sizeOf(context).width * 0.85,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
                  child: Text(type.toUpperCase(), style: GoogleFonts.barlowCondensed(color: kWebWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                if (type == 'subtitles')
                  _MobileTrackTile(label: 'DISABLED', isActive: current.id == 'no', onTap: () { _vm.setSubtitleTrack(SubtitleTrack.no()); Navigator.pop(ctx); }),
                ...tracks.map((t) => _MobileTrackTile(
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
            width: MediaQuery.sizeOf(context).width * 0.8,
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: speeds.map((s) => _MobileTrackTile(
                label: '${s}X SPEED',
                isActive: (s - current).abs() < 0.01,
                onTap: () { _vm.setRate(s); Navigator.pop(ctx); },
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showFitModal() {
    final fits = {BoxFit.contain: 'CONTAIN', BoxFit.cover: 'COVER', BoxFit.fill: 'STRETCH'};
    showGeneralDialog(
      context: context,
      barrierColor: kWebBlack.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.8,
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fits.entries.map((e) => _MobileTrackTile(
                label: e.value,
                isActive: _vm.videoFit == e.key,
                onTap: () { _vm.setVideoFit(e.key); Navigator.pop(ctx); },
              )).toList(),
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
            width: MediaQuery.sizeOf(context).width * 0.8,
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((m) => _MobileTrackTile(
                label: m == 0 ? 'OFF' : '$m MINUTES',
                isActive: _vm.sleepMinutesRemaining == m,
                onTap: () { _vm.setSleepTimer(m); Navigator.pop(ctx); },
              )).toList(),
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
            width: MediaQuery.sizeOf(context).width * 0.9,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(color: kWebSurface, border: Border.all(color: kWebWhite, width: 2)),
            child: ListenableBuilder(
              listenable: _vm,
              builder: (_, child) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MobileSyncTile(label: 'AUDIO OFFSET', value: _vm.audioDelay, onChanged: _vm.setAudioDelay),
                  _MobileSyncTile(label: 'SUBTITLE OFFSET', value: _vm.subDelay, onChanged: _vm.setSubtitleDelay),
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
// MOBILE UI SUB-COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _MobileIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isPrimary;
  final bool isDestructive;

  const _MobileIconBtn({required this.icon, required this.onTap, this.size = 44, this.isPrimary = false, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPrimary ? kWebWhite : Colors.transparent,
          border: Border.all(color: isDestructive ? Colors.redAccent : kWebBorder),
        ),
        child: Icon(icon, color: isPrimary ? kWebBlack : (isDestructive ? Colors.redAccent : kWebWhite), size: size * 0.5),
      ),
    );
  }
}

class _MobileSidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MobileSidebarItem({required this.label, required this.icon, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : kWebWhite;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.dmMono(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

class _MobileTrackTile extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MobileTrackTile({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? kWebWhite.withValues(alpha: 0.05) : Colors.transparent,
          border: Border(bottom: BorderSide(color: kWebBorder)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: GoogleFonts.dmMono(color: isActive ? kWebWhite : kWebText, fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal))),
            if (isActive) const Icon(LucideIcons.check, color: kWebWhite, size: 12),
          ],
        ),
      ),
    );
  }
}

class _MobileSyncTile extends StatelessWidget {
  final String label;
  final double value;
  final Function(double) onChanged;

  const _MobileSyncTile({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kWebBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmMono(color: kWebTextMuted, fontSize: 8, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            children: [
              _MobileIconBtn(icon: LucideIcons.minus, size: 32, onTap: () => onChanged(value - 0.1)),
              Expanded(child: Center(child: Text('${value.toStringAsFixed(1)}S', style: GoogleFonts.dmMono(color: kWebWhite, fontSize: 16, fontWeight: FontWeight.bold)))),
              _MobileIconBtn(icon: LucideIcons.plus, size: 32, onTap: () => onChanged(value + 0.1)),
            ],
          ),
        ],
      ),
    );
  }
}
