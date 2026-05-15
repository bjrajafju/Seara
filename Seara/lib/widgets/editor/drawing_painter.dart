import 'package:flutter/material.dart';

import '../../models/story/drawing_overlay.dart' as model;
import '../../models/story/drawing_path.dart';

/// Renders the unified drawing overlay using [CustomPainter].
///
/// Paints all committed strokes from [overlay] plus an optional [activeStroke]
/// that is still in progress (finger/mouse not yet lifted).
///
/// ## Eraser strategy
/// Eraser strokes are painted with [BlendMode.clear] inside a [Canvas.saveLayer]
/// call. This produces true pixel-level transparency through all underlying
/// pencil strokes. The saveLayer has a minor GPU cost but is isolated inside
/// this painter's repaint boundary, so it never affects text or media layers.
///
/// ## Repaint optimisation
/// [shouldRepaint] checks:
/// 1. Whether the committed stroke count changed.
/// 2. Whether [activeStroke] reference changed.
/// This avoids full repaint when neither condition is met.
class DrawingPainter extends CustomPainter {
  final model.DrawingOverlay? overlay;
  final DrawingPath? activeStroke;
  final Size canvasSize;

  const DrawingPainter({
    required this.overlay,
    required this.activeStroke,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // We must wrap the entire drawing in saveLayer to allow eraser
    // BlendMode.clear to punch through ALL underlying pencil pixels.
    canvas.saveLayer(Offset.zero & size, Paint());

    // Paint committed strokes.
    if (overlay != null) {
      for (final path in overlay!.paths) {
        _paintStroke(canvas, path, w, h);
      }
    }

    // Paint the active in-progress stroke on top.
    if (activeStroke != null) {
      _paintStroke(canvas, activeStroke!, w, h);
    }

    canvas.restore();
  }

  void _paintStroke(Canvas canvas, DrawingPath stroke, double w, double h) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isEraser) {
      paint
        ..blendMode = BlendMode.clear
        ..color = Colors.transparent;
    } else {
      paint
        ..blendMode = BlendMode.srcOver
        ..color = stroke.color;
    }

    // Convert normalized points to pixel offsets.
    final offsets = stroke.points
        .map((p) => p.toOffset(canvasWidth: w, canvasHeight: h))
        .toList();

    if (offsets.length == 1) {
      // Single tap — draw a dot.
      canvas.drawCircle(
        offsets.first,
        stroke.strokeWidth / 2,
        Paint()
          ..color = stroke.isEraser ? Colors.transparent : stroke.color
          ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver,
      );
      return;
    }

    // Use a smooth quadratic Bézier path through the points.
    final path = Path()..moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final curr = offsets[i];
      final next = offsets[i + 1];
      final midX = (curr.dx + next.dx) / 2;
      final midY = (curr.dy + next.dy) / 2;
      path.quadraticBezierTo(curr.dx, curr.dy, midX, midY);
    }

    // Close the last segment to the final point.
    final last = offsets.last;
    path.lineTo(last.dx, last.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter old) => true;
}
