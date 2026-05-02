// presentation/player/player_screen.dart
// ============================================================================
// STREAMZ — Universal Media Player Screen (Cinematic UI & D-Pad Optimized)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/models/media_item.dart';
import 'player_viewmodel.dart';

class PlayerScreen extends StatefulWidget {
  final List<MediaItem> items;
  final int startIndex;
  final bool isPathBased;

  const PlayerScreen({super.key, required this.items, required this.startIndex, this.isPathBased = false});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerViewModel _vm;

  final FocusScopeNode _osdFocusScope = FocusScopeNode();
  final FocusNode _primaryFocusNode = FocusNode();

  bool _wasOSDVisible = true;

  bool get _isTV => MediaQuery.sizeOf(context).width >= DS.bpTV;

  @override
  void initState() {
    super.initState();
    _vm = PlayerViewModel();
    _vm.load(items: widget.items, startIndex: widget.startIndex, isPathBased: widget.isPathBased).then((_) {
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
            child: Stack(fit: StackFit.expand, children: [_buildMediaLayer(), _buildGestureFeedback(), _buildOSD()]),
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
            errorBuilder: (_, _, _) => const Icon(PhosphorIconsRegular.image, color: Colors.white24, size: 64),
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
                child: Container(
                  width: sz,
                  height: sz,
                  decoration: BoxDecoration(
                    color: DS.surface1,
                    border: Border.all(color: DS.borderDefault, width: _isTV ? 2 : 1),
                    boxShadow: [BoxShadow(color: DS.accent.withValues(alpha: 0.15), blurRadius: 40)],
                  ),
                  child: NetworkImageFade(url: _vm.thumbUrl, fit: BoxFit.cover, fallbackIcon: PhosphorIconsFill.musicNote),
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
      child: Video(controller: _vm.videoController, controls: NoVideoControls),
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
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildTopBar(), _buildBottomBar()]),
      ),
    ),
  );

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
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [DS.bg.withValues(alpha: 0.85), Colors.transparent],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BrutalistPlayerBtn(icon: PhosphorIconsRegular.x, size: btnSz, onTap: () => Navigator.pop(context)),
              SizedBox(width: hPad * 0.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('NOW PLAYING // ${_typeLabel(item)}', style: AppTheme.theme.textTheme.labelSmall?.copyWith(color: DS.accent, fontSize: (c.maxWidth * 0.01).clamp(9.0, 14.0))),
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
              Text('${_vm.currentIndex + 1}/${_vm.playlist.length}', style: AppTheme.theme.textTheme.labelSmall?.copyWith(fontSize: (c.maxWidth * 0.01).clamp(9.0, 16.0), color: Colors.white70)),
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
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [DS.bg.withValues(alpha: 0.95), Colors.transparent],
            ),
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
                      BrutalistPlayerBtn(icon: PhosphorIconsFill.skipBack, size: skipSz, onTap: _vm.prev),
                      SizedBox(width: gap),
                      _buildCenterBtn(item, mainSz),
                      SizedBox(width: gap),
                      BrutalistPlayerBtn(icon: PhosphorIconsFill.skipForward, size: skipSz, onTap: _vm.next),
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
      return BrutalistPlayerBtn(icon: PhosphorIconsFill.rewind, size: sz, onTap: () => _vm.seekRelative(const Duration(seconds: -10)));
    }
    if (item?.isImage == true) {
      return Text('FILE ${_vm.currentIndex + 1} OF ${_vm.playlist.length}', style: AppTheme.theme.textTheme.labelMedium?.copyWith(fontSize: _isTV ? 14 : 10, color: Colors.white70));
    }
    return const SizedBox.shrink();
  }

  Widget _buildCenterBtn(MediaItem? item, double sz) {
    if (item?.isImage == true) {
      return BrutalistPlayerBtn(
        focusNode: _primaryFocusNode,
        autoFocus: true,
        isPrimary: true,
        icon: PhosphorIconsFill.stop,
        size: sz,
        onTap: () => Navigator.pop(context),
      );
    }
    return StreamBuilder<bool>(
      stream: _vm.player.stream.playing,
      builder: (_, s) {
        final playing = s.data ?? false;
        return BrutalistPlayerBtn(
          focusNode: _primaryFocusNode,
          autoFocus: true,
          isPrimary: true,
          icon: playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play,
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
      return BrutalistPlayerBtn(icon: PhosphorIconsFill.fastForward, size: sz, onTap: () => _vm.seekRelative(const Duration(seconds: 10)));
    }
    if (item?.isAudio == true) {
      return BrutalistPlayerBtn(icon: PhosphorIconsFill.stop, size: sz, onTap: () => Navigator.pop(context));
    }
    return const SizedBox.shrink();
  }

  static const _typeLabels = {'video': 'VID', 'audio': 'AUD', 'image': 'IMG'};
  String _typeLabel(MediaItem? item) => _typeLabels[item?.type] ?? 'SYS';
}