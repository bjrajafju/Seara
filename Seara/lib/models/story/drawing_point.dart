import 'dart:ui';

/// A single point in a drawing stroke.
///
/// Coordinates are **normalized** (0.0 → 1.0), relative to the canvas size,
/// matching the coordinate system used by [TextOverlay].
/// Denormalize with [toOffset] when painting.
class DrawingPoint {
  /// Horizontal position as a fraction of canvas width (0.0 – 1.0).
  final double x;

  /// Vertical position as a fraction of canvas height (0.0 – 1.0).
  final double y;

  const DrawingPoint({required this.x, required this.y});

  /// Converts to a Flutter [Offset] by multiplying against the canvas size.
  ///
  /// [canvasWidth] and [canvasHeight] are the rendered canvas dimensions
  /// in logical pixels.
  Offset toOffset({required double canvasWidth, required double canvasHeight}) {
    return Offset(x * canvasWidth, y * canvasHeight);
  }
}
