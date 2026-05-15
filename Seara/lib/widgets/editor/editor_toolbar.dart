import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import '../../services/video_export/export_result.dart';
import '../../services/video_export_service.dart';
import '../../utils/export/export_saver.dart';

/// Vertical toolbar positioned on the right side of the editor screen,
/// OUTSIDE the [StoryViewport] composition frame.
///
/// Provides:
/// - **Text** — creates a new [TextOverlay].
/// - **Draw** — toggles freehand drawing mode.
/// - **Mute** — toggles video audio (video stories only).
/// - **Export** — image PNG (image stories) or MP4 via FFmpeg (video stories).
class EditorToolbar extends StatelessWidget {
  /// Key for the full-composition [RepaintBoundary] (image export).
  final GlobalKey canvasKey;

  /// Key for the overlay-only [RepaintBoundary] (video export FFmpeg pipeline).
  final GlobalKey overlayKey;

  const EditorToolbar({
    super.key,
    required this.canvasKey,
    required this.overlayKey,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final isBusy = controller.isExporting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Add Text (disabled in drawing mode) ──────────────────────────────
        _ToolbarButton(
          icon: Icons.text_fields,
          label: 'Text',
          onPressed: (isBusy || controller.isDrawingMode)
              ? null
              : () => context.read<EditorController>().addTextLayer(),
        ),

        const SizedBox(height: 12),

        // ── Draw mode toggle ─────────────────────────────────────────────────
        _ToolbarButton(
          icon: Icons.edit_rounded,
          label: controller.isDrawingMode ? 'Done' : 'Draw',
          active: controller.isDrawingMode,
          onPressed: isBusy
              ? null
              : () => context.read<EditorController>().toggleDrawingMode(),
        ),

        // ── Mute toggle (video stories only) ─────────────────────────────────
        if (controller.isVideoStory) ...[
          const SizedBox(height: 12),
          _ToolbarButton(
            icon: controller.isMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            label: controller.isMuted ? 'Muted' : 'Sound',
            active: !controller.isMuted,
            onPressed: isBusy
                ? null
                : () => context.read<EditorController>().toggleMute(),
          ),
        ],

        const SizedBox(height: 20),

        // ── Export ───────────────────────────────────────────────────────────
        _ToolbarButton(
          icon: isBusy ? Icons.hourglass_top : Icons.download_rounded,
          label: isBusy ? '…' : 'Save',
          onPressed: isBusy ? null : () => _onExport(context, controller),
        ),
      ],
    );
  }

  // ── Export dispatch ────────────────────────────────────────────────────────

  Future<void> _onExport(
    BuildContext context,
    EditorController controller,
  ) async {
    if (controller.isVideoStory) {
      await _exportVideo(context, controller);
    } else {
      await _exportImage(context, controller);
    }
  }

  // ── Image export (Phase 1–3 pipeline, unchanged) ───────────────────────────

  Future<void> _exportImage(
    BuildContext context,
    EditorController controller,
  ) async {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    final boundary =
        canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    final bytes = await controller.captureImage(boundary, pixelRatio);
    if (!context.mounted) return;

    if (bytes == null) {
      _snack(context, 'Export failed. Please try again.', isError: true);
      return;
    }

    try {
      final path = await saveExportedImage(bytes);
      if (!context.mounted) return;
      _snack(context, 'Saved: $path');
    } catch (_) {
      if (!context.mounted) return;
      _snack(context, 'Could not save file.', isError: true);
    }
  }

  // ── Video export (Phase 4 FFmpeg pipeline) ─────────────────────────────────

  Future<void> _exportVideo(
    BuildContext context,
    EditorController controller,
  ) async {
    // Set exporting flag in controller for UI feedback.
    controller.beginExporting();

    try {
      const service = VideoExportService();
      final result = await service.exportVideo(
        draft: controller.draft,
        overlayKey: overlayKey,
      );

      if (!context.mounted) return;

      switch (result) {
        case ExportSuccess(:final outputPath):
          _snack(context, 'Saved: $outputPath');
        case ExportFailure(:final error):
          _snack(context, 'Export failed: $error', isError: true);
        case ExportUnsupported(:final reason):
          _snack(
            context,
            reason,
            isError: false,
            duration: const Duration(seconds: 5),
          );
      }
    } finally {
      controller.endExporting();
    }
  }

  void _snack(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? Colors.redAccent.shade400
            : const Color(0xFF2E7D32),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ── Toolbar button ─────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white12,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? Colors.white : Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? Colors.black : Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.black : Colors.white,
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
