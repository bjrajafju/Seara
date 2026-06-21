import 'package:flutter/material.dart';

/// Enforces the global story composition frame on every platform.
///
/// All story-related UI **must** be wrapped in this widget:
/// - Camera preview
/// - Editor canvas
/// - Text editing area
/// - Future: drawing tools, stickers, crop UI, media transforms
///
/// On desktop/web, the result is a centred phone-sized canvas against a
/// black background — intentionally not a responsive full-width editor.
///
/// ## Sizing constants
/// All other code must reference [maxWidth] and [aspectRatio] from here.
/// Do **not** hardcode `420` or `9 / 16` anywhere else.
class StoryViewport extends StatelessWidget {
  // Sizing constants

  /// Maximum width of the story composition area in logical pixels.
  ///
  /// Approximates a large modern phone (e.g. iPhone 15 Pro Max) in portrait.
  /// On screens narrower than this value, the viewport will shrink to match
  /// the screen width while maintaining [aspectRatio].
  static const double maxWidth = 420.0;

  /// Portrait story aspect ratio (9 wide : 16 tall).
  /// Value: 0.5625
  static const double aspectRatio = 9.0 / 16.0;

  // Widget

  final Widget child;

  const StoryViewport({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Stable neutral background outside the composition frame.
      // Never transparent — avoids inconsistent desktop appearance.
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Explicitly calculate the portrait dimensions based on the
            // available space and the 9:16 target ratio.

            double availableWidth = constraints.maxWidth;
            double availableHeight = constraints.maxHeight;

            // Target width is the lesser of the available width or our maximum.
            double targetWidth = availableWidth < maxWidth
                ? availableWidth
                : maxWidth;

            // Calculate corresponding height for a 9:16 ratio.
            double targetHeight = targetWidth / aspectRatio;

            // If the calculated height is taller than the screen,
            // we must scale down based on height instead.
            if (targetHeight > availableHeight) {
              targetHeight = availableHeight;
              targetWidth = targetHeight * aspectRatio;
            }

            return ClipRect(
              // ClipRect ensures that any overlays (like text) that are dragged
              // outside the 9:16 frame are visually hidden, maintaining the
              // illusion of a physical phone screen.
              child: SizedBox(
                width: targetWidth,
                height: targetHeight,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
