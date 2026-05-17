import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/story_engine_controller.dart';

/// Segmented progress bars shown at the top of the story viewer.
///
/// - Past stories: fully filled (white).
/// - Current story: animated fill driven by [StoryEngineController.progressController].
/// - Future stories: empty (white12).
class StoryProgressBars extends StatelessWidget {
  const StoryProgressBars({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<StoryEngineController>();
    final totalStories = engine.currentUser.stories.length;
    final currentIndex = engine.storyIndex;

    return Row(
      children: List.generate(totalStories, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < totalStories - 1 ? 3 : 0),
            child: _StorySegment(
              state: i < currentIndex
                  ? _SegmentState.past
                  : i == currentIndex
                      ? _SegmentState.active
                      : _SegmentState.future,
              progressAnimation: engine.progressController,
            ),
          ),
        );
      }),
    );
  }
}

enum _SegmentState { past, active, future }

class _StorySegment extends StatelessWidget {
  final _SegmentState state;
  final AnimationController progressAnimation;

  const _StorySegment({
    required this.state,
    required this.progressAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 2.5,
        child: switch (state) {
          _SegmentState.past => const ColoredBox(color: Colors.white),
          _SegmentState.future =>
            const ColoredBox(color: Color(0x33FFFFFF)),
          _SegmentState.active => AnimatedBuilder(
              animation: progressAnimation,
              builder: (_, __) => LinearProgressIndicator(
                value: progressAnimation.value,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 2.5,
              ),
            ),
        },
      ),
    );
  }
}
