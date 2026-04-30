import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';

/// Minimal toolbar for the story editor.
///
/// Provides two actions:
/// - **Add Text** — creates a new [TextOverlay] and opens the edit modal.
/// - **Download** — exports the canvas to a PNG file via [EditorController].
class EditorToolbar extends StatelessWidget {
  /// The [GlobalKey] of the [RepaintBoundary] wrapping the canvas.
  /// Passed to [EditorController.exportToImage].
  final GlobalKey canvasKey;

  const EditorToolbar({super.key, required this.canvasKey});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Add Text ──────────────────────────────────────────────────────
          _ToolbarButton(
            icon: Icons.text_fields,
            label: 'Text',
            onPressed: controller.isExporting
                ? null
                : () => context.read<EditorController>().addTextLayer(),
          ),

          // ── Download ──────────────────────────────────────────────────────
          _ToolbarButton(
            icon: controller.isExporting
                ? Icons.hourglass_top
                : Icons.download_rounded,
            label: controller.isExporting ? 'Saving…' : 'Save',
            onPressed: controller.isExporting ? null : () => _export(context),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final controller = context.read<EditorController>();

    // Resolve the RenderRepaintBoundary synchronously before any await,
    // so the linter and runtime never see BuildContext used across async gaps.
    final boundary =
        canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    final path = await controller.exportToImage(boundary, pixelRatio);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path != null ? 'Saved to: $path' : 'Export failed. Please try again.',
        ),
        backgroundColor: path != null
            ? Colors.green.shade700
            : Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private toolbar button
// ---------------------------------------------------------------------------

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
