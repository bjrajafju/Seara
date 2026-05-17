import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/story_engine_controller.dart';

/// Transparent overlay that intercepts gestures and forwards intents
/// exclusively to [StoryEngineController].
///
/// Rules (from architecture plan):
/// - Tap left  (< 30% width)  → engine.previous()
/// - Tap right (> 30% width)  → engine.next()
/// - Long press start          → engine.pause()
/// - Long press end            → engine.resume()
/// - This widget NEVER touches PageController directly.
class StoryGestureLayer extends StatelessWidget {
  final Widget child;

  const StoryGestureLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final engine = context.read<StoryEngineController>();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth * 0.30) {
          engine.previous();
        } else {
          engine.next();
        }
      },
      onLongPressStart: (_) => engine.pause(),
      onLongPressEnd: (_) => engine.resume(),
      child: child,
    );
  }
}
