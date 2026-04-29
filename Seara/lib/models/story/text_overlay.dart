import 'overlay_element.dart';

/// A text element placed on top of story media.
///
/// Position, scale, and rotation are all independent so the UI can
/// manipulate them via gestures without conflicting with font metrics.
class TextOverlay extends OverlayElement {
  /// Horizontal position as a fraction of canvas width (0.0 – 1.0).
  double x;

  /// Vertical position as a fraction of canvas height (0.0 – 1.0).
  double y;

  /// Visual scale factor applied to the rendered text.
  /// Independent of [fontSize] — fontSize only affects line breaking.
  double scale;

  /// Rotation angle in radians.
  double rotation;

  /// Font size in logical pixels. Controls text layout / line wrapping,
  /// NOT the visual size on screen (that is controlled by [scale]).
  double fontSize;

  /// The text content to display.
  String content;

  TextOverlay({
    required super.id,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.fontSize = 24.0,
    this.content = '',
    required super.zIndex,
  });

  /// Convenience: bring this overlay to the front by assigning the
  /// given [maxZIndex] + 1. Call this when the user drags / selects it.
  void bringToFront(int currentMaxZIndex) {
    zIndex = currentMaxZIndex + 1;
  }
}
