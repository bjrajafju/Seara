import 'dart:ui';

import 'drawing_point.dart';

/// A single freehand stroke in a drawing overlay.
///
/// Each stroke is recorded as a series of [DrawingPoint]s
/// along with visual properties (color, width, and eraser flag).
class DrawingPath {
  /// Ordered list of points that form this stroke.
  final List<DrawingPoint> points;

  /// Color of this stroke. Ignored when [isEraser] is true.
  final Color color;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  /// When true, this stroke erases underlying pixels using [BlendMode.clear].
  /// When false, this is a normal pencil stroke.
  final bool isEraser;

  const DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });
}
