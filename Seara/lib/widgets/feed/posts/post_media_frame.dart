import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../models/feed/post_crop_transform.dart';
import '../../../models/feed/post_media_source.dart';
import '../../../utils/media/platform_media_factory.dart';

class PostMediaFrame extends StatelessWidget {
  const PostMediaFrame({
    super.key,
    required this.source,
    required this.crop,
    this.thumbnailUrl,
    this.editable = false,
    this.autoplayVideo = true,
    this.onCropChanged,
  });

  final PostMediaSource source;
  final PostCropTransform crop;
  final String? thumbnailUrl;
  final bool editable;
  final bool autoplayVideo;
  final ValueChanged<PostCropTransform>? onCropChanged;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameSize = Size(constraints.maxWidth, constraints.maxHeight);
          final clamped = crop.clamped();
          final media = ClipRect(
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

          if (!editable || onCropChanged == null) return media;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              onCropChanged!(
                clamped
                    .copyWith(
                      offsetX:
                          clamped.offsetX + details.delta.dx / frameSize.width,
                      offsetY:
                          clamped.offsetY + details.delta.dy / frameSize.height,
                    )
                    .clamped(),
              );
            },
            child: media,
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

  void _initVideoIfNeeded() {
    if (!widget.source.isVideo) return;
    final video = PostVideoController(
      source: widget.source.displaySource,
      autoplay: widget.autoplayVideo,
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
          Video(
            controller: video.controller,
            controls: NoVideoControls,
            fit: BoxFit.cover,
            fill: Colors.black,
          ),
        if (widget.thumbnailUrl != null && !(video?.firstFrameReady ?? false))
          Image.network(widget.thumbnailUrl!, fit: BoxFit.cover),
        if (!(video?.firstFrameReady ?? false) && widget.thumbnailUrl == null)
          const _PostVideoPlaceholder(),
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
  PostVideoController({required this.source, required this.autoplay})
    : player = Player() {
    controller = VideoController(player);
  }

  static const _firstFrameTimeout = Duration(milliseconds: 700);

  final String source;
  final bool autoplay;
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
      await player.setVolume(0);
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
    await player.setVolume(0);
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
