import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

class VideoLightboxScreen extends StatefulWidget {
  const VideoLightboxScreen({super.key, required this.videoUrl, this.fileName});

  final String videoUrl;
  final String? fileName;

  @override
  State<VideoLightboxScreen> createState() => _VideoLightboxScreenState();
}

class _VideoLightboxScreenState extends State<VideoLightboxScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _controlsFade;
  late FocusNode _focusNode;

  bool _initialized = false;
  bool _showControls = true;
  bool _isSeeking = false;
  bool _isMuted = false;
  bool _isDownloading = false;
  bool _isFullscreen = false;

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();

    _focusNode = FocusNode();

    _controlsFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              _controller.play();
              _autoHideControls();
              _focusNode.requestFocus();
            }
          })
          .catchError((_) {
            if (mounted) setState(() => _initialized = false);
          });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  /// Releases controllers and subscriptions used by this widget
  void dispose() {
    _focusNode.dispose();
    _controlsFade.dispose();
    _controller.dispose();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  /// Shows controls temporarily
  void _showControlsTemporarily() {
    if (!_showControls) {
      setState(() => _showControls = true);
      _controlsFade.forward();
    }
    _autoHideControls();
  }

  /// Toggles controls
  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsFade.forward();
      _autoHideControls();
    } else {
      _controlsFade.reverse();
    }
  }

  /// Auto hide controls
  void _autoHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showControls && !_isSeeking) {
        setState(() => _showControls = false);
        _controlsFade.reverse();
      }
    });
  }

  /// Handles key event
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlay();
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final target = _controller.value.position + const Duration(seconds: 10);
      _controller.seekTo(target);
      _showControlsTemporarily();
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final target = _controller.value.position - const Duration(seconds: 10);
      _controller.seekTo(target < Duration.zero ? Duration.zero : target);
      _showControlsTemporarily();
      return;
    }
  }

  /// Toggles play
  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
    _showControlsTemporarily();
  }

  /// Seek
  Future<void> _seek(double value) async {
    final target = Duration(
      milliseconds: (value * _controller.value.duration.inMilliseconds).round(),
    );
    await _controller.seekTo(target);
  }

  /// Toggles mute
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
    _showControlsTemporarily();
  }

  /// Toggles fullscreen
  void _toggleFullscreen() {
    if (kIsWeb) return;
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _showControlsTemporarily();
  }

  /// Download
  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      downloadFile(widget.videoUrl, widget.fileName ?? 'video.mp4');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao fazer download.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Formats a duration for display
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.inverseSurface,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onHover: (_) => _showControlsTemporarily(),
          child: GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(child: _buildVideoContent()),
                FadeTransition(
                  opacity: _controlsFade,
                  child: _buildControlsOverlay(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds video content
  Widget _buildVideoContent() {
    if (!_initialized) {
      return CircularProgressIndicator(
        color: Theme.of(context).colorScheme.onInverseSurface,
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }

  /// Builds controls overlay
  Widget _buildControlsOverlay() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildTopBar(),
        const Spacer(),
        if (_initialized)
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.scrim.withAlpha(140),
              ),
              child: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: cs.onInverseSurface,
                size: 40,
              ),
            ),
          ),
        const Spacer(),
        if (_initialized) _buildBottomBar(),
      ],
    );
  }

  /// Builds top bar
  Widget _buildTopBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.inverseSurface.withAlpha(200), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.close_rounded, color: cs.onInverseSurface),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.fileName ?? 'Video',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onInverseSurface,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _isDownloading
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onInverseSurface,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      Icons.download_rounded,
                      color: cs.onInverseSurface,
                    ),
                    tooltip: 'Download',
                    onPressed: _download,
                  ),
            if (kIsWeb)
              Tooltip(
                message: 'Espaco: play/pause | Esc: fechar | ← →: 10s',
                child: IconButton(
                  icon: Icon(
                    Icons.keyboard_rounded,
                    color: cs.onInverseSurface.withAlpha(140),
                    size: 20,
                  ),
                  onPressed: null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds bottom bar
  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [cs.inverseSurface.withAlpha(200), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.onInverseSurface.withAlpha(70),
                  thumbColor: cs.primary,
                  overlayColor: cs.primary.withAlpha(60),
                ),
                child: Slider(
                  value: progress.toDouble(),
                  onChangeStart: (_) {
                    _isSeeking = true;
                    _controller.pause();
                  },
                  onChanged: (v) => _seek(v),
                  onChangeEnd: (v) {
                    _isSeeking = false;
                    _seek(v);
                    _controller.play();
                    _autoHideControls();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      _fmt(position),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onInverseSurface,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      ' / ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onInverseSurface.withAlpha(160),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _fmt(duration),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onInverseSurface.withAlpha(160),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        _isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: cs.onInverseSurface,
                      ),
                      onPressed: _toggleMute,
                    ),
                    const SizedBox(width: 16),
                    if (!kIsWeb)
                      IconButton(
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: cs.onInverseSurface,
                        ),
                        onPressed: _toggleFullscreen,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
