import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import '../../models/story/drawing_path.dart';
import '../../models/story/drawing_point.dart';
import 'drawing_painter.dart';

/// Transparent gesture layer that captures pointer input for freehand drawing.
///
/// ## Architecture
/// - Uses [Listener] (not [GestureDetector]) for raw pointer events.
///   This avoids gesture arena delays and provides immediate, low-latency input
///   from touch, mouse, and stylus on all platforms.
/// - Only the **primary button** is accepted (left mouse, first touch point).
///   Secondary mouse buttons and extra touch points are ignored.
/// - A local [ValueNotifier] drives the [CustomPaint] repaint during an active
///   stroke. This means the painter repaints at pointer frequency (~60–120 Hz)
///   WITHOUT calling [EditorController.notifyListeners], which would rebuild
///   the full editor tree (text widgets, toolbar, etc.).
/// - On stroke completion ([PointerUpEvent]), the finished [DrawingPath] is
///   committed to [EditorController] via a single [notifyListeners] call.
///
/// ## Z-index
/// This widget is rendered ABOVE [BaseMediaWidget] but BELOW all
/// [TextLayerWidget]s. This is enforced by [EditorCanvas] stack ordering.
class DrawingCanvasWidget extends StatefulWidget {
  const DrawingCanvasWidget({super.key});

  @override
  State<DrawingCanvasWidget> createState() => _DrawingCanvasWidgetState();
}

class _DrawingCanvasWidgetState extends State<DrawingCanvasWidget> {
  /// Holds the currently-in-progress stroke.
  /// Notified on every pointer move — drives painter repaint without
  /// rebuilding the parent widget tree.
  final ValueNotifier<DrawingPath?> _activeStroke = ValueNotifier(null);

  @override
  void dispose() {
    _activeStroke.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final isDrawing = controller.isDrawingMode;

    return IgnorePointer(
      ignoring: !isDrawing,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          // Primary button only: touch (kind=touch) or left mouse button.
          if (e.buttons != kPrimaryButton &&
              e.kind != PointerDeviceKind.touch) {
            return;
          }
          _beginStroke(context, e.localPosition);
        },
        onPointerMove: (e) {
          if (_activeStroke.value == null) return;
          _extendStroke(context, e.localPosition);
        },
        onPointerUp: (_) => _commitStroke(context),
        onPointerCancel: (_) => _cancelStroke(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return RepaintBoundary(
              // Isolated repaint scope — only this painter repaints on each
              // pointer move, not the full editor.
              child: ValueListenableBuilder<DrawingPath?>(
                valueListenable: _activeStroke,
                builder: (context, active, _) {
                  return CustomPaint(
                    size: size,
                    painter: DrawingPainter(
                      overlay: controller.draft.drawingOverlay,
                      activeStroke: active,
                      canvasSize: size,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // Stroke lifecycle

  void _beginStroke(BuildContext context, Offset localPos) {
    final ctrl = context.read<EditorController>();
    final size = _canvasSize(context);
    if (size == null) return;

    final point = DrawingPoint(
      x: (localPos.dx / size.width).clamp(0.0, 1.0),
      y: (localPos.dy / size.height).clamp(0.0, 1.0),
    );

    _activeStroke.value = DrawingPath(
      points: [point],
      color: ctrl.drawingColor,
      strokeWidth: ctrl.brushThickness,
      isEraser: ctrl.isEraserActive,
    );
  }

  void _extendStroke(BuildContext context, Offset localPos) {
    final current = _activeStroke.value;
    if (current == null) return;
    final size = _canvasSize(context);
    if (size == null) return;

    final point = DrawingPoint(
      x: (localPos.dx / size.width).clamp(0.0, 1.0),
      y: (localPos.dy / size.height).clamp(0.0, 1.0),
    );

    // Replace the ValueNotifier value with a new DrawingPath to trigger
    // ValueListenableBuilder rebuild.
    _activeStroke.value = DrawingPath(
      points: [...current.points, point],
      color: current.color,
      strokeWidth: current.strokeWidth,
      isEraser: current.isEraser,
    );
  }

  void _commitStroke(BuildContext context) {
    final stroke = _activeStroke.value;
    _activeStroke.value = null;
    if (stroke == null || stroke.points.isEmpty) return;

    // Single notifyListeners call to persist the completed stroke.
    context.read<EditorController>().commitStroke(stroke);
  }

  void _cancelStroke() {
    _activeStroke.value = null;
  }

  Size? _canvasSize(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.size;
  }
}
