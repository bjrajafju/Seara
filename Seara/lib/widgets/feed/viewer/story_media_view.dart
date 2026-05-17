import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../../controllers/story_engine_controller.dart';
import '../../../models/feed/feed_story.dart';

/// Renders the active story media — either a full-screen image or a video.
///
/// Reads the current story and active player from [StoryEngineController].
/// Video rendering delegates to [media_kit_video] VideoController.
class StoryMediaView extends StatefulWidget {
  const StoryMediaView({super.key});

  @override
  State<StoryMediaView> createState() => _StoryMediaViewState();
}

class _StoryMediaViewState extends State<StoryMediaView> {
  VideoController? _videoController;
  Player? _trackedPlayer;

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<StoryEngineController>();
    final story = engine.currentStory;
    final player = engine.activePlayer;

    // Rebuild VideoController only when the player instance changes.
    if (player != _trackedPlayer) {
      _trackedPlayer = player;
      _videoController = player != null ? VideoController(player) : null;
    }

    return SizedBox.expand(
      child: story.isVideo
          ? _buildVideo(story, _videoController)
          : _buildImage(story),
    );
  }

  Widget _buildVideo(FeedStory story, VideoController? controller) {
    if (controller == null) {
      return _loadingBox();
    }

    return Video(
      controller: controller,
      controls: NoVideoControls,
      fit: BoxFit.cover,
    );
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

  Widget _loadingBox() {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _errorBox() {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 64),
      ),
    );
  }
}
