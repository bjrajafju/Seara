import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import 'base_media_widget.dart';
import 'drawing_canvas_widget.dart';
import 'text_layer_widget.dart';

/// The main editor canvas.
///
/// Renders in Z order:
/// 1. [BaseMediaWidget]       — base image or video (z = 0, bottom).
/// 2. [DrawingCanvasWidget]   — unified drawing overlay (z = 1).
/// 3. [TextLayerWidget]s      — one per [TextOverlay], sorted by zIndex (top).
///
/// Wraps the full composition in a [RepaintBoundary] keyed by [repaintKey]
/// for image-story export (captures everything including media).
///
/// Additionally, renders an invisible [RepaintBoundary] keyed by
/// [overlayRepaintKey] that captures ONLY the drawing + text overlays on a
/// transparent background. This boundary is used by [VideoExportService]
/// to generate `overlay.png` for FFmpeg composition without capturing the
/// hardware video texture.
class EditorCanvas extends StatelessWidget {
  /// Key for the full-composition boundary (image export).
  final GlobalKey repaintKey;

  /// Key for the overlay-only boundary (video export FFmpeg pipeline).
  final GlobalKey overlayRepaintKey;

  const EditorCanvas({
    super.key,
    required this.repaintKey,
    required this.overlayRepaintKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          return _CanvasContent(
            canvasSize: canvasSize,
            overlayRepaintKey: overlayRepaintKey,
          );
        },
      ),
    );
  }
}

class _CanvasContent extends StatelessWidget {
  final Size canvasSize;
  final GlobalKey overlayRepaintKey;

  const _CanvasContent({
    required this.canvasSize,
    required this.overlayRepaintKey,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final layers = controller.layersInZOrder;
    final media = controller.draft.media;
    final isDrawing = controller.isDrawingMode;

    return GestureDetector(
      onTap: isDrawing
          ? null
          : () => context.read<EditorController>().deselectAll(),
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Overlay export boundary (Hidden at the bottom)
            // Strategy: We use Opacity(0.01) instead of 0.0 to force Flutter
            // to paint the boundary (otherwise it's optimized away).
            // By putting it at the bottom of the stack, it's effectively
            // covered by the video/media while still being valid for capture.
            IgnorePointer(
              child: Opacity(
                opacity: 0.01,
                child: RepaintBoundary(
                  key: overlayRepaintKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Colors.transparent),
                      const DrawingCanvasWidget(),
                      for (final layer in layers)
                        TextLayerWidget(
                          key: ValueKey('overlay_${layer.id}'),
                          layer: layer,
                          canvasSize: canvasSize,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // z = 0 — Base media (covers the overlay boundary).
            if (media.isNotEmpty) BaseMediaWidget(media: media.first),

            // z = 1 — Drawing overlay (interactive layer).
            const DrawingCanvasWidget(),

            // z = 2+ — Text layers.
            for (final layer in layers)
              TextLayerWidget(
                key: ValueKey(layer.id),
                layer: layer,
                canvasSize: canvasSize,
              ),
          ],
        ),
      ),
    );
  }
}
