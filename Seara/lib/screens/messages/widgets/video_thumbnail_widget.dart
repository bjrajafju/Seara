import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../video_lightbox_screen.dart';

class VideoThumbnailWidget extends StatefulWidget {
  const VideoThumbnailWidget({
    super.key,
    required this.url,
    this.fileName,
    this.width,
    this.height,
    this.borderRadius,
    this.playIconSize,
  });

  final String url;
  final String? fileName;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double? playIconSize;

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  late final Player _player;
  late final VideoController _controller;
  bool _frameReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _loadPosterFrame();
  }

  Future<void> _loadPosterFrame() async {
    try {
      await _player.setVolume(0);
      await _player.open(Media(widget.url), play: false);
      await _player.play();
      await Future.any<void>([
        _controller.waitUntilFirstFrameRendered,
        Future<void>.delayed(const Duration(milliseconds: 120)),
      ]);
      if (!mounted) return;
      await _player.pause();
      setState(() => _frameReady = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _openLightbox(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Theme.of(context).colorScheme.scrim,
        pageBuilder: (_, __, ___) => VideoLightboxScreen(
          videoUrl: widget.url,
          fileName: widget.fileName,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = widget.borderRadius ?? BorderRadius.circular(10);
    return GestureDetector(
      onTap: () => _openLightbox(context),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!_hasError)
              ClipRRect(
                borderRadius: radius,
                child: SizedBox.expand(
                  child: Video(
                    controller: _controller,
                    controls: NoVideoControls,
                    fit: BoxFit.cover,
                    fill: cs.surfaceContainerHighest,
                  ),
                ),
              ),
            if (!_frameReady)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: radius,
                  ),
                ),
              ),
            Container(
              width: widget.playIconSize ?? 52,
              height: widget.playIconSize ?? 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.scrim.withAlpha(140),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: cs.onInverseSurface,
                size: (widget.playIconSize != null) ? (widget.playIconSize! * 0.65) : 34,
              ),
            ),
            if (widget.fileName != null)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  widget.fileName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _frameReady
                        ? cs.onInverseSurface
                        : cs.onSurface.withAlpha(200),
                    fontSize: 11,
                    overflow: TextOverflow.ellipsis,
                    shadows: _frameReady
                        ? const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
