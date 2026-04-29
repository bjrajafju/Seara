import 'dart:ui';

import 'drawing_point.dart';

/// A single freehand stroke in a drawing overlay.
///
/// Each stroke is recorded as a series of [DrawingPoint]s
/// along with visual properties (color, width).
class DrawingPath {
  /// Ordered list of points that form this stroke.
  final List<DrawingPoint> points;

  /// Color of this stroke.
  final Color color;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  const DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}
