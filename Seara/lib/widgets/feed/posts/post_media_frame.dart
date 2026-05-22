import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../models/feed/post_crop_transform.dart';
import '../../../models/feed/post_media_source.dart';
import '../../../services/feed/audio_preferences_service.dart';
import '../../../utils/media/platform_media_factory.dart';

class PostMediaFrame extends StatelessWidget {
  const PostMediaFrame({
    super.key,
    required this.source,
    required this.crop,
    this.thumbnailUrl,
    this.autoplayVideo = true,
  });

  final PostMediaSource source;
  final PostCropTransform crop;
  final String? thumbnailUrl;
  final bool autoplayVideo;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameSize = Size(constraints.maxWidth, constraints.maxHeight);
          final clamped = crop.clamped();
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(
                    clamped.offsetX * frameSize.width,
                    clamped.offsetY * frameSize.height,
                  ),
                  child: Transform.scale(
                    scale: clamped.scale,
                    child: _PostMediaContent(
                      source: source,
                      thumbnailUrl: thumbnailUrl,
                      autoplayVideo: autoplayVideo,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostMediaContent extends StatefulWidget {
  const _PostMediaContent({
    required this.source,
    required this.autoplayVideo,
    this.thumbnailUrl,
  });

  final PostMediaSource source;
  final bool autoplayVideo;
  final String? thumbnailUrl;

  @override
  State<_PostMediaContent> createState() => _PostMediaContentState();
}

class _PostMediaContentState extends State<_PostMediaContent>
    with WidgetsBindingObserver {
  PostVideoController? _video;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideoIfNeeded();
    AudioPreferencesService.isMutedNotifier.addListener(_onMuteChanged);
  }

  @override
  void didUpdateWidget(covariant _PostMediaContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.displaySource != widget.source.displaySource ||
        oldWidget.autoplayVideo != widget.autoplayVideo) {
      _video?.dispose();
      _video = null;
      _initVideoIfNeeded();
    }
  }

  void _onMuteChanged() {
    if (!mounted) return;
    final isMuted = AudioPreferencesService.isMutedNotifier.value;
    _video?.player.setVolume(isMuted ? 0 : 100);
    setState(() {});
  }

  void _initVideoIfNeeded() {
    if (!widget.source.isVideo) return;
    final video = PostVideoController(
      source: widget.source.displaySource,
      autoplay: widget.autoplayVideo,
      isMuted: AudioPreferencesService.isMutedNotifier.value,
    );
    _video = video;
    video.controller.waitUntilFirstFrameRendered.then((_) {
      video.markFirstFrameReady();
      if (mounted) setState(() {});
    });
    unawaited(
      video.warmUpAndMaybePlay().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.autoplayVideo) {
      unawaited(_video?.ensurePlayingAfterAttach());
    }
  }

  @override
  void dispose() {
    AudioPreferencesService.isMutedNotifier.removeListener(_onMuteChanged);
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.source.isImage) {
      return _buildImage();
    }

    final video = _video;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (video != null)
          GestureDetector(
            onTap: () {
              final currentMuted = AudioPreferencesService.isMutedNotifier.value;
              AudioPreferencesService.setMuted(!currentMuted);
            },
            child: Video(
              controller: video.controller,
              controls: NoVideoControls,
              fit: BoxFit.cover,
              fill: Colors.black,
            ),
          ),
        if (widget.thumbnailUrl != null && !(video?.firstFrameReady ?? false))
          Image.network(widget.thumbnailUrl!, fit: BoxFit.cover),
        if (!(video?.firstFrameReady ?? false) && widget.thumbnailUrl == null)
          const _PostVideoPlaceholder(),

        // Mute state scale & fade micro-animation overlay in the center
        if (video != null && video.firstFrameReady)
          Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: AudioPreferencesService.isMutedNotifier,
              builder: (context, isMuted, _) {
                return _MuteOverlayIcon(isMuted: isMuted);
              },
            ),
          ),

        // Mute toggle icon in the bottom-left corner of the video media
        if (video != null && video.firstFrameReady)
          Positioned(
            left: 12,
            bottom: 12,
            child: ValueListenableBuilder<bool>(
              valueListenable: AudioPreferencesService.isMutedNotifier,
              builder: (context, isMuted, _) {
                return GestureDetector(
                  onTap: () {
                    AudioPreferencesService.setMuted(!isMuted);
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildImage() {
    final source = widget.source;
    if (source.bytes != null) {
      return Image.memory(source.bytes!, fit: BoxFit.cover);
    }
    final path = source.displaySource;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.cover);
    }
    return buildLocalFileImage(path, BoxFit.cover);
  }
}

class PostVideoController {
  PostVideoController({
    required this.source,
    required this.autoplay,
    required this.isMuted,
  }) : player = Player() {
    controller = VideoController(player);
  }

  static const _firstFrameTimeout = Duration(milliseconds: 700);

  final String source;
  final bool autoplay;
  final bool isMuted;
  final Player player;
  late final VideoController controller;

  bool _disposed = false;
  bool _firstFrameReady = false;
  Future<void>? _warmFuture;

  bool get firstFrameReady => _firstFrameReady;

  void markFirstFrameReady() => _firstFrameReady = true;

  Future<void> warmUpAndMaybePlay() {
    return _warmFuture ??= _runWarmUp();
  }

  Future<void> _runWarmUp() async {
    try {
      await player.setPlaylistMode(PlaylistMode.none);
      await player.setVolume(isMuted ? 0 : 100);
      await player.open(Media(source), play: false);
      if (_disposed) return;

      await player.play();
      try {
        await controller.waitUntilFirstFrameRendered.timeout(
          _firstFrameTimeout,
        );
        _firstFrameReady = true;
      } catch (_) {}
      if (_disposed) return;

      if (autoplay) {
        await ensurePlayingAfterAttach();
      } else {
        await player.pause();
      }
    } catch (_) {
      if (!_disposed) {
        try {
          await player.pause();
        } catch (_) {}
      }
    }
  }

  Future<void> ensurePlayingAfterAttach() async {
    if (_disposed) return;
    final currentlyMuted = AudioPreferencesService.isMutedNotifier.value;
    await player.setVolume(currentlyMuted ? 0 : 100);
    if (player.state.completed) {
      await player.seek(Duration.zero);
    }
    if (!player.state.playing) {
      await player.play();
    }
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!_disposed && !player.state.playing) {
        await player.play();
      }
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(player.dispose());
  }
}

class _PostVideoPlaceholder extends StatelessWidget {
  const _PostVideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF191919), Color(0xFF060606)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white30, size: 52),
      ),
    );
  }
}

class _MuteOverlayIcon extends StatefulWidget {
  const _MuteOverlayIcon({required this.isMuted});
  final bool isMuted;

  @override
  State<_MuteOverlayIcon> createState() => _MuteOverlayIconState();
}

class _MuteOverlayIconState extends State<_MuteOverlayIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.1).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.9).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(0.9), weight: 50),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _MuteOverlayIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMuted != widget.isMuted) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_opacityAnimation.value == 0.0) return const SizedBox.shrink();
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.black54,
              child: Icon(
                widget.isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }
}
