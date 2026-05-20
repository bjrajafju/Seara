import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'download_helper_io.dart'
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
  late final Player _player;
  late final VideoController _videoController;
  late final AnimationController _controlsFade;
  late final FocusNode _focusNode;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _initialized = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isSeeking = false;
  bool _isMuted = false;
  bool _isDownloading = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _player = Player();
    _videoController = VideoController(_player);

    _controlsFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );

    _wirePlayerListeners();
    unawaited(_openVideo());
  }

  void _wirePlayerListeners() {
    void repaint(dynamic _) {
      if (mounted) setState(() {});
    }

    _subscriptions
      ..add(_player.stream.playing.listen(repaint))
      ..add(
        _player.stream.completed.listen((completed) {
          if (!mounted) return;
          setState(() {});
          if (completed == true) {
            _showControlsTemporarily();
          }
        }),
      )
      ..add(_player.stream.position.listen(repaint))
      ..add(_player.stream.duration.listen(repaint))
      ..add(_player.stream.buffering.listen(repaint))
      ..add(_player.stream.width.listen(repaint))
      ..add(_player.stream.height.listen(repaint));
  }

  Future<void> _openVideo() async {
    try {
      await _player.setPlaylistMode(PlaylistMode.none);
      await _player.open(Media(widget.videoUrl), play: true);
      await _videoController.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
      if (!mounted) return;
      setState(() => _initialized = true);
      _autoHideControls();
      _focusNode.requestFocus();
    } catch (_) {
      if (mounted) {
        setState(() {
          _initialized = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _focusNode.dispose();
    _controlsFade.dispose();
    _player.dispose();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _showControlsTemporarily() {
    if (!_showControls) {
      setState(() => _showControls = true);
      _controlsFade.forward();
    }
    _autoHideControls();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsFade.forward();
      _autoHideControls();
    } else {
      _controlsFade.reverse();
    }
  }

  void _autoHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showControls && !_isSeeking && _player.state.playing) {
        setState(() => _showControls = false);
        _controlsFade.reverse();
      }
    });
  }

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
      _seekTo(_player.state.position + const Duration(seconds: 10));
      _showControlsTemporarily();
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final target = _player.state.position - const Duration(seconds: 10);
      _seekTo(target < Duration.zero ? Duration.zero : target);
      _showControlsTemporarily();
    }
  }

  Future<void> _togglePlay() async {
    if (_player.state.completed) {
      await _player.seek(Duration.zero);
    }

    if (_player.state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    _showControlsTemporarily();
  }

  Future<void> _seek(double value) async {
    final duration = _player.state.duration;
    final target = Duration(
      milliseconds: (value * duration.inMilliseconds).round(),
    );
    await _seekTo(target);
  }

  Future<void> _seekTo(Duration target) async {
    final duration = _player.state.duration;
    final maxMs = duration.inMilliseconds;
    final clamped = maxMs > 0
        ? Duration(milliseconds: target.inMilliseconds.clamp(0, maxMs))
        : target;
    await _player.seek(clamped);
  }

  Future<void> _toggleMute() async {
    _isMuted = !_isMuted;
    await _player.setVolume(_isMuted ? 0 : 100);
    if (mounted) setState(() {});
    _showControlsTemporarily();
  }

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

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      await downloadFile(widget.videoUrl, widget.fileName ?? 'video.mp4');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Download concluído.')));
      }
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

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
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

  Widget _buildVideoContent() {
    if (_hasError) {
      return Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onInverseSurface.withAlpha(180),
        size: 56,
      );
    }

    final width = _player.state.width;
    final height = _player.state.height;
    final aspectRatio = width != null && height != null && height > 0
        ? width / height
        : 16 / 9;

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: aspectRatio,
          child: Video(
            controller: _videoController,
            controls: NoVideoControls,
            fit: BoxFit.contain,
            fill: Theme.of(context).colorScheme.inverseSurface,
          ),
        ),
        if (!_initialized)
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.onInverseSurface,
          ),
      ],
    );
  }

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
                _player.state.playing
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
                message: 'Espaco: play/pause | Esc: fechar | <- ->: 10s',
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

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final duration = _player.state.duration;
    final position = _player.state.position;
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
                    _player.pause();
                  },
                  onChanged: (v) => _seek(v),
                  onChangeEnd: (v) {
                    _isSeeking = false;
                    _seek(v);
                    _player.play();
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
