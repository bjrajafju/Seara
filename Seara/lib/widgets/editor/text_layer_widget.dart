import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import '../../models/story/text_overlay.dart';

/// Renders and handles gestures for a single [TextOverlay] layer.
///
/// Gesture handling strategy (unified scale recogniser):
/// - [onScaleStart]  → snapshot current transform, mark gesture as started.
/// - [onScaleUpdate] → update position / scale / rotation via controller.
/// - [onScaleEnd]    → clear snapshot.
/// - [onTap]         → open edit modal ONLY if no movement occurred
///                     (threshold: 8 logical pixels).
///
/// Text is rendered in a [SizedBox] with a fixed [maxWidth] (80 % of canvas
/// width) so that [TextAlign.center] and `\n` line breaks render correctly.
class TextLayerWidget extends StatefulWidget {
  final TextOverlay layer;
  final Size canvasSize;

  const TextLayerWidget({
    super.key,
    required this.layer,
    required this.canvasSize,
  });

  @override
  State<TextLayerWidget> createState() => _TextLayerWidgetState();
}

class _TextLayerWidgetState extends State<TextLayerWidget> {
  _GestureBaseline? _baseline;

  static const double _movementThreshold = 8.0;

  /// Maximum text width: 80 % of the canvas width.
  double get _maxWidth => widget.canvasSize.width * 0.8;

  EditorController get _ctrl => context.read<EditorController>();

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final canvas = widget.canvasSize;

    // De-normalise: (0.5, 0.5) → canvas centre.
    final dx = layer.x * canvas.width;
    final dy = layer.y * canvas.height;

    // Anchor offsets shift the text so that (dx, dy) is the visual centre
    // of the text block (not its top-left corner).
    final anchorX = _maxWidth / 2;
    final anchorY = _estimateHalfHeight(layer);

    // In drawing mode, all text interaction is disabled. The Listener inside
    // DrawingCanvasWidget owns all pointer events during that state.
    final isDrawing = context.watch<EditorController>().isDrawingMode;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: isDrawing,
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: _handleTap,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
          child: Stack(
            children: [
              Positioned(
                left: dx,
                top: dy,
                child: Transform.translate(
                  offset: Offset(-anchorX, -anchorY),
                  child: Transform.rotate(
                    angle: layer.rotation,
                    // alignment: Alignment.center is the default — rotation
                    // pivots around the centre of the text block.
                    child: Transform.scale(
                      scale: layer.scale,
                      child: _TextContent(layer: layer, maxWidth: _maxWidth),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  void _handleTap() {
    if (!(_baseline?.hasMoved ?? false)) {
      _ctrl.openEditModal(widget.layer.id);
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _ctrl.bringToFront(widget.layer.id);
    _baseline = _GestureBaseline(
      focalPoint: details.localFocalPoint,
      x: widget.layer.x,
      y: widget.layer.y,
      scale: widget.layer.scale,
      rotation: widget.layer.rotation,
    );
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final b = _baseline;
    if (b == null) return;

    final delta = details.localFocalPoint - b.focalPoint;
    if (delta.distance > _movementThreshold) b.hasMoved = true;

    final canvas = widget.canvasSize;
    final newX = b.x + delta.dx / canvas.width;
    final newY = b.y + delta.dy / canvas.height;
    final newScale = b.scale * details.scale;
    final newRotation = b.rotation + details.rotation;

    _ctrl.updatePosition(widget.layer.id, newX, newY);
    _ctrl.updateScaleAndRotation(widget.layer.id, newScale, newRotation);
  }

  void _handleScaleEnd(ScaleEndDetails _) {
    _baseline = null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Estimates half the rendered text height so the anchor centres vertically.
  ///
  /// Uses a line-height factor of 1.2 and counts actual `\n` breaks.
  double _estimateHalfHeight(TextOverlay layer) {
    final lineCount = layer.content.split('\n').length;
    return layer.fontSize * 1.2 * lineCount / 2;
  }
}

// ---------------------------------------------------------------------------
// Private text content widget
// ---------------------------------------------------------------------------

class _TextContent extends StatelessWidget {
  final TextOverlay layer;

  /// Constrains the text to a fixed width so that:
  /// - [TextAlign.center] takes effect.
  /// - `\n` line breaks respect the available width.
  final double maxWidth;

  const _TextContent({required this.layer, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxWidth,
      child: Text(
        layer.content.isEmpty ? ' ' : layer.content,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: layer.fontSize,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          height: 1.2,
          shadows: const [
            Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(1, 1)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gesture baseline value object
// ---------------------------------------------------------------------------

class _GestureBaseline {
  final Offset focalPoint;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  bool hasMoved = false;

  _GestureBaseline({
    required this.focalPoint,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
  });
}
