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
/// - [onTap]         → open edit modal ONLY if the gesture did not move
///                     (movement threshold: 8 logical pixels).
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
  // Gesture baseline — set on scaleStart, cleared on scaleEnd.
  _GestureBaseline? _baseline;

  // Movement threshold in logical pixels.
  static const double _movementThreshold = 8.0;

  EditorController get _ctrl => context.read<EditorController>();

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final canvas = widget.canvasSize;

    final dx = layer.x * canvas.width;
    final dy = layer.y * canvas.height;

    return Positioned.fill(
      child: GestureDetector(
        // Absorb events so canvas background GestureDetector is not triggered.
        behavior: HitTestBehavior.deferToChild,
        onTap: _handleTap,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: _handleScaleEnd,
        child: Stack(
          children: [
            // Invisible full-area hit target so only the text area is tappable.
            Positioned(
              left: dx,
              top: dy,
              child: Transform.translate(
                offset: Offset(-_textAnchorX(layer), -_textAnchorY(layer)),
                child: Transform.rotate(
                  angle: layer.rotation,
                  child: Transform.scale(
                    scale: layer.scale,
                    child: _TextContent(layer: layer),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  void _handleTap() {
    final hasMoved = _baseline?.hasMoved ?? false;
    if (!hasMoved) {
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

  /// Rough half-width estimate for centring the transform origin.
  double _textAnchorX(TextOverlay layer) =>
      layer.fontSize * layer.content.length * 0.3;

  double _textAnchorY(TextOverlay layer) => layer.fontSize * 0.5;
}

// ---------------------------------------------------------------------------
// Private text content widget — separate to isolate text rebuilds.
// ---------------------------------------------------------------------------

class _TextContent extends StatelessWidget {
  final TextOverlay layer;

  const _TextContent({required this.layer});

  @override
  Widget build(BuildContext context) {
    return Text(
      layer.content.isEmpty ? ' ' : layer.content,
      style: TextStyle(
        fontSize: layer.fontSize,
        color: Colors.white,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(1, 1)),
        ],
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
