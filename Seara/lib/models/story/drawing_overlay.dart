import 'drawing_path.dart';
import 'overlay_element.dart';

/// A freehand drawing layer placed on top of story media.
///
/// Always rendered behind text overlays — its [zIndex] should
/// stay lower than any [TextOverlay.zIndex].
///
/// Supports only two operations: adding strokes and clearing all.
/// No undo/redo.
class DrawingOverlay extends OverlayElement {
  /// All strokes that make up this drawing, in chronological order.
  final List<DrawingPath> paths;

  DrawingOverlay({
    required super.id,
    List<DrawingPath>? paths,
    super.zIndex = -1, // default below all text overlays
  }) : paths = paths ?? [];

  /// Append a completed stroke to the drawing.
  void addPath(DrawingPath path) {
    paths.add(path);
  }

  /// Remove all strokes (full clear).
  void clearAll() {
    paths.clear();
  }

  /// Whether the drawing has any visible content.
  bool get isEmpty => paths.isEmpty;
}
