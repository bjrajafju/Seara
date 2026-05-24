import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/feed/post_crop_transform.dart';
import '../../../models/feed/post_media_source.dart';
import '../../../services/feed/audio_preferences_service.dart';
import '../../../services/feed/post_playback_coordinator.dart';
import '../../../utils/media/platform_media_factory.dart';
import '../../../utils/media/blob_url_helper.dart'
    if (dart.library.html) '../../../utils/media/blob_url_helper_web.dart';

class PostMediaFrame extends StatelessWidget {
  const PostMediaFrame({
    super.key,
    required this.postId,
    required this.source,
    required this.crop,
    this.thumbnailUrl,
    this.autoplayVideo = true,
    this.isFullFrame = false,
  });

  final String postId;
  final PostMediaSource source;
  final PostCropTransform crop;
  final String? thumbnailUrl;
  final bool autoplayVideo;
  final bool isFullFrame;

  @override
  Widget build(BuildContext context) {
    final clamped = crop.clamped();
    final cw = clamped.cropWidth;
    final ch = clamped.cropHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth = constraints.maxWidth;
        // The base frame is always 9:16 relative to the parent width
        final baseWidth = parentWidth;
        final baseHeight = parentWidth * 16 / 9;

        final widgetWidth = isFullFrame ? baseWidth : baseWidth * cw;
        final widgetHeight = isFullFrame ? baseHeight : baseHeight * ch;

        final cropCenterX = isFullFrame
            ? 0.5
            : (clamped.cropLeft + clamped.cropRight) / 2;
        final cropCenterY = isFullFrame
            ? 0.5
            : (clamped.cropTop + clamped.cropBottom) / 2;

        Widget content = _PostMediaContent(
          postId: postId,
          source: source,
          thumbnailUrl: thumbnailUrl,
          autoplayVideo: autoplayVideo,
        );

        if (!clamped.isBaked) {
          content = Transform.scale(
            scale: clamped.scale,
            child: Transform.translate(
              offset: Offset(
                (clamped.offsetX - (cropCenterX - 0.5)) * baseWidth,
                (clamped.offsetY - (cropCenterY - 0.5)) * baseHeight,
              ),
              child: content,
            ),
          );
          content = OverflowBox(
            alignment: Alignment.center,
            minWidth: baseWidth,
            maxWidth: baseWidth,
            minHeight: baseHeight,
            maxHeight: baseHeight,
            child: content,
          );
        }

        return VisibilityDetector(
          key: ValueKey('post_vis_$postId'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction > 0.05) {
              final RenderBox? box = context.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                final position = box.localToGlobal(Offset.zero);
                final widgetCenter = position.dy + box.size.height / 2;
                final viewportHeight = MediaQuery.of(context).size.height;
                final viewportCenter = viewportHeight / 2;
                final distance = (widgetCenter - viewportCenter).abs();

                PostPlaybackCoordinator().reportVisibility(
                  postId,
                  PostPlaybackMetrics(
                    visibleFraction: info.visibleFraction,
                    distanceToCenter: distance,
                  ),
                );
              }
            } else {
              PostPlaybackCoordinator().unregister(postId);
            }
          },
          child: SizedBox(
            width: widgetWidth,
            height: widgetHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _PostMediaContent extends StatefulWidget {
  const _PostMediaContent({
    required this.postId,
    required this.source,
    required this.autoplayVideo,
    this.thumbnailUrl,
  });

  final String postId;
  final PostMediaSource source;
  final bool autoplayVideo;
  final String? thumbnailUrl;

  @override
  State<_PostMediaContent> createState() => _PostMediaContentState();
}

class _PostMediaContentState extends State<_PostMediaContent>
    with WidgetsBindingObserver {
  PostVideoController? _video;
  bool _isUserHolding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioPreferencesService.isMutedNotifier.addListener(_onMuteChanged);
    PostPlaybackCoordinator().addListener(_onCoordinatorUpdate);
  }

  @override
  void didUpdateWidget(covariant _PostMediaContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.displaySource != widget.source.displaySource ||
        oldWidget.autoplayVideo != widget.autoplayVideo ||
        oldWidget.postId != widget.postId) {
      if (oldWidget.postId != widget.postId) {
        PostPlaybackCoordinator().unregister(oldWidget.postId);
      }
      _video?.dispose();
      _video = null;
      if (PostPlaybackCoordinator().isVisible(widget.postId)) {
        _initVideoIfNeeded();
      }
    }
  }

  void _onCoordinatorUpdate() {
    if (!mounted) return;

    final isVisible = PostPlaybackCoordinator().isVisible(widget.postId);
    if (isVisible && _video == null) {
      _initVideoIfNeeded();
    } else if (!isVisible && _video != null) {
      _video?.dispose();
      _video = null;
      setState(() {});
    }

    _updatePlaybackState();
  }

  void _onMuteChanged() {
    if (!mounted) return;
    final isMuted = AudioPreferencesService.isMutedNotifier.value;
    _video?.player.setVolume(isMuted ? 0 : 100);
  }

  void _initVideoIfNeeded() {
    if (!widget.source.isVideo || _video != null) return;

    final video = PostVideoController(
      source: widget.source.displaySource,
      webBytes: widget.source.bytes,
      autoplay: false,
      isMuted: AudioPreferencesService.isMutedNotifier.value,
    );
    _video = video;

    // Use a listener to mark first frame ready instead of waitUntilFirstFrameRendered
    // to avoid potential hangs.
    video.controller.waitUntilFirstFrameRendered.then((_) {
      if (mounted && _video == video) {
        video.markFirstFrameReady();
        setState(() {});
      }
    });

    unawaited(
      video.warmUpAndMaybePlay().then((_) {
        if (mounted && _video == video) {
          setState(() {});
          _updatePlaybackState();
        }
      }),
    );
  }

  void _updatePlaybackState() {
    if (_video == null) return;

    final isActive = PostPlaybackCoordinator().activePostId == widget.postId;
    final shouldPlay = isActive && widget.autoplayVideo && !_isUserHolding;

    if (shouldPlay) {
      unawaited(_video?.ensurePlayingAfterAttach());
    } else {
      unawaited(_video?.player.pause());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePlaybackState();
    } else {
      unawaited(_video?.player.pause());
    }
  }

  @override
  void dispose() {
    PostPlaybackCoordinator().unregister(widget.postId);
    PostPlaybackCoordinator().removeListener(_onCoordinatorUpdate);
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
            onLongPressStart: (_) {
              _isUserHolding = true;
              _updatePlaybackState();
            },
            onLongPressEnd: (_) {
              _isUserHolding = false;
              _updatePlaybackState();
            },
            onLongPressCancel: () {
              _isUserHolding = false;
              _updatePlaybackState();
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
  PostVideoController._({
    required String effectiveSource,
    String? webBlobUrl,
    required this.autoplay,
    required this.isMuted,
  }) : player = Player(),
       _effectiveSource = effectiveSource,
       _webBlobUrl = webBlobUrl {
    controller = VideoController(player);
  }

  factory PostVideoController({
    required String source,
    Uint8List? webBytes,
    required bool autoplay,
    required bool isMuted,
  }) {
    String? blobUrl;
    String effective = source;
    if (kIsWeb && webBytes != null) {
      blobUrl = createBlobUrl(webBytes);
      effective = blobUrl!;
    }
    return PostVideoController._(
      effectiveSource: effective,
      webBlobUrl: blobUrl,
      autoplay: autoplay,
      isMuted: isMuted,
    );
  }

  static const _firstFrameTimeout = Duration(milliseconds: 700);

  final String _effectiveSource;
  String? _webBlobUrl;
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
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.setVolume(isMuted ? 0 : 100);
      await player.open(Media(_effectiveSource), play: false);
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
    await warmUpAndMaybePlay();
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
    if (_webBlobUrl != null) {
      revokeBlobUrl(_webBlobUrl);
    }
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
