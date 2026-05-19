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
class StoryMediaView extends StatelessWidget {
  const StoryMediaView({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<StoryEngineController>();
    final story = engine.currentStory;
    final player = engine.activePlayer;

    return SizedBox.expand(
      child: story.isVideo ? _buildVideo(story, player) : _buildImage(story),
    );
  }

  Widget _buildVideo(FeedStory story, Player? player) {
    if (player == null) {
      return _loadingBox();
    }

    return StoryVideoPlayerWidget(key: ValueKey(player), player: player);
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
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white24,
          size: 64,
        ),
      ),
    );
  }
}

/// Dedicated stateful widget to manage the lifecycle of a [VideoController].
///
/// By separating this widget, the [VideoController] is created exactly once
/// in [initState] and disposed when the widget is unmounted, avoiding texture
/// allocation race conditions on player transitions.
class StoryVideoPlayerWidget extends StatefulWidget {
  final Player player;

  const StoryVideoPlayerWidget({super.key, required this.player});

  @override
  State<StoryVideoPlayerWidget> createState() => _StoryVideoPlayerWidgetState();
}

class _StoryVideoPlayerWidgetState extends State<StoryVideoPlayerWidget> {
  late final VideoController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(widget.player);
  }

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: _videoController,
      controls: NoVideoControls,
      fit: BoxFit.cover,
    );
  }
}
