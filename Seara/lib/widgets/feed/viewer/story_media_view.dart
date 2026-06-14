import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../../controllers/story_engine_controller.dart';
import '../../../models/feed/feed_story.dart';
import '../../../services/feed/story_preload_service.dart';

/// Renders the active story media — either a full-screen image or a video.
///
/// Reads the current story and active player from [StoryEngineController].
/// Video rendering delegates to [media_kit_video] VideoController.
class StoryMediaView extends StatelessWidget {
  const StoryMediaView({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<StoryEngineController>();
    final story = engine.currentStory;
    final video = engine.activeVideo;

    return SizedBox.expand(
      child: story.isVideo ? _buildVideo(story, video) : _buildImage(story),
    );
  }

  Widget _buildVideo(FeedStory story, StoryPreloadedVideo? video) {
    if (video == null) {
      return _videoPlaceholder();
    }

    return StoryVideoPlayerWidget(key: ValueKey(video.story.id), video: video);
  }

  Widget _buildImage(FeedStory story) {
    return Image.network(
      story.mediaUrl,
      fit: BoxFit.cover,
      frameBuilder: (_, child, frame, __) {
        if (frame == null) return _loadingBox();
        return child;
      },
      errorBuilder: (_, __, ___) => _errorBox(),
    );
  }

  Widget _loadingBox() => _videoPlaceholder();

  Widget _videoPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151515), Color(0xFF050505)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 54),
      ),
    );
  }

  Widget _errorBox() {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white24,
          size: 64,
        ),
      ),
    );
  }
}

/// Dedicated stateful widget to render a cached [VideoController].
///
/// The video stays mounted underneath the placeholder so media_kit can render
/// the first frame. The placeholder is removed only after that frame arrives.
class StoryVideoPlayerWidget extends StatefulWidget {
  final StoryPreloadedVideo video;

  const StoryVideoPlayerWidget({super.key, required this.video});

  @override
  State<StoryVideoPlayerWidget> createState() => _StoryVideoPlayerWidgetState();
}

class _StoryVideoPlayerWidgetState extends State<StoryVideoPlayerWidget> {
  bool _firstFrameReady = false;

  @override
  void initState() {
    super.initState();

    _firstFrameReady = widget.video.isFirstFrameReady;

    final engine = context.read<StoryEngineController>();

    widget.video.player.stream.completed.listen((completed) {
      if (!mounted || !completed) return;
      engine.next();
    });

    widget.video.player.stream.playing.listen((playing) {
      if (!mounted) return;

      final engine = context.read<StoryEngineController>();

      if (playing && !engine.isPaused) {
        if (!engine.progressController.isAnimating) {
          engine.progressController.forward();
        }
      } else {
        engine.progressController.stop();
      }
    });

    if (_firstFrameReady && !engine.mediaReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          engine.onVideoFirstFrameReady();
        }
      });
    }

    widget.video.controller.waitUntilFirstFrameRendered.then((_) {
      if (!mounted) return;

      widget.video.markFirstFrameReady();

      final engine = context.read<StoryEngineController>();

      if (!engine.mediaReady) {
        engine.onVideoFirstFrameReady();
      }

      setState(() => _firstFrameReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: widget.video.controller,
          controls: NoVideoControls,
          fit: BoxFit.cover,
        ),
        if (!_firstFrameReady)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _firstFrameReady ? 0 : 1,
                duration: const Duration(milliseconds: 120),
                child: const _StoryVideoPlaceholder(),
              ),
            ),
          ),
      ],
    );
  }
}

class _StoryVideoPlaceholder extends StatelessWidget {
  const _StoryVideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151515), Color(0xFF050505)],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
