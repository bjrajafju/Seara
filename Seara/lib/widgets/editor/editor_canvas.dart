import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import 'base_media_widget.dart';
import 'text_layer_widget.dart';

/// The main editor canvas.
///
/// Wraps the entire composition in a [RepaintBoundary] (keyed externally for
/// export) and renders:
/// 1. [BaseMediaWidget] — base image or video (fills the canvas).
/// 2. [TextLayerWidget] — one per [TextOverlay], sorted by zIndex.
///
/// A background [GestureDetector] deselects all layers when the user
/// taps empty canvas space.
class EditorCanvas extends StatelessWidget {
  /// The [GlobalKey] to attach to the [RepaintBoundary].
  /// Owned by [StoryEditorScreen] and shared with the export button.
  final GlobalKey repaintKey;

  const EditorCanvas({super.key, required this.repaintKey});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          return _CanvasContent(canvasSize: canvasSize);
        },
      ),
    );
  }
}

class _CanvasContent extends StatelessWidget {
  final Size canvasSize;

  const _CanvasContent({required this.canvasSize});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final layers = controller.layersInZOrder;
    final media = controller.draft.media;

    return GestureDetector(
      // Tapping blank canvas deselects all layers.
      onTap: () => context.read<EditorController>().deselectAll(),
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base media — always at z = 0.
            if (media.isNotEmpty) BaseMediaWidget(media: media.first),

            // Text layers — rendered in ascending zIndex order.
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
