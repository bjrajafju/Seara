import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import '../../utils/export/export_saver.dart';

/// Vertical toolbar positioned on the right side of the editor screen,
/// OUTSIDE the [StoryViewport] composition frame.
///
/// Provides:
/// - **Text** — creates a new [TextOverlay] and opens the edit modal.
/// - **Save** — exports canvas to PNG (image stories only).
///   Disabled with an explanatory [SnackBar] for video stories.
class EditorToolbar extends StatelessWidget {
  final GlobalKey canvasKey;

  const EditorToolbar({super.key, required this.canvasKey});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();

    // Determine export button state based on draft type and export status.
    final bool isVideo = !controller.canExport;
    final bool isBusy = controller.isExporting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Add Text ────────────────────────────────────────────────────────
        _ToolbarButton(
          icon: Icons.text_fields,
          label: 'Text',
          onPressed: isBusy
              ? null
              : () => context.read<EditorController>().addTextLayer(),
        ),

        const SizedBox(height: 20),

        // ── Save / Export ────────────────────────────────────────────────────
        // Disabled for video stories — real video export is a future phase.
        _ToolbarButton(
          icon: isVideo
              ? Icons.videocam_off_rounded
              : isBusy
              ? Icons.hourglass_top
              : Icons.download_rounded,
          label: isVideo
              ? 'N/A'
              : isBusy
              ? '…'
              : 'Save',
          onPressed: isBusy
              ? null
              : isVideo
              ? () => _showVideoExportMessage(context)
              : () => _export(context),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _export(BuildContext context) async {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final controller = context.read<EditorController>();

    // Resolve the render object synchronously before any await.
    final boundary =
        canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    // Step 1: controller captures pixels → Uint8List.
    final bytes = await controller.captureImage(boundary, pixelRatio);
    if (!context.mounted) return;

    if (bytes == null) {
      _showSnackBar(context, 'Export failed. Please try again.', isError: true);
      return;
    }

    // Step 2: platform utility saves or downloads the bytes.
    try {
      final result = await saveExportedImage(bytes);
      if (!context.mounted) return;
      _showSnackBar(context, 'Saved: $result');
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Could not save file.', isError: true);
    }
  }

  void _showVideoExportMessage(BuildContext context) {
    _showSnackBar(
      context,
      'Video export is not supported yet. '
      'Text overlays are visible during playback.',
      isError: false,
      duration: const Duration(seconds: 4),
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: duration,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private toolbar button — icon above label, rounded card.
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
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
