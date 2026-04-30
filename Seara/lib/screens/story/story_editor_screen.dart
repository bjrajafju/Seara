import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import '../../models/story/story_draft.dart';
import '../../widgets/editor/editor_canvas.dart';
import '../../widgets/editor/editor_toolbar.dart';
import '../../widgets/editor/text_edit_modal.dart';

/// Root screen for the story editor.
///
/// Receives a [StoryDraft] from the capture screen and wires up:
/// - [EditorController] (via [ChangeNotifierProvider])
/// - [EditorCanvas]      — the composited, exportable preview
/// - [EditorToolbar]     — Add Text + Download
/// - [TextEditModal]     — conditionally shown over the canvas
class StoryEditorScreen extends StatefulWidget {
  final StoryDraft draft;

  const StoryEditorScreen({super.key, required this.draft});

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  /// Shared [GlobalKey] for the [RepaintBoundary] in [EditorCanvas].
  /// Passed to both the canvas (for capture) and the toolbar (for export).
  final GlobalKey _canvasKey = GlobalKey();

  late final EditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(widget.draft);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Consumer<EditorController>(
            builder: (context, controller, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── Canvas (RepaintBoundary wraps everything below) ────────
                  Positioned.fill(
                    bottom: _toolbarHeight,
                    child: EditorCanvas(repaintKey: _canvasKey),
                  ),

                  // ── Toolbar ───────────────────────────────────────────────
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _toolbarHeight,
                    child: EditorToolbar(canvasKey: _canvasKey),
                  ),

                  // ── Back button ───────────────────────────────────────────
                  Positioned(top: 8, left: 8, child: _BackButton()),

                  // ── Text edit modal (conditional) ─────────────────────────
                  if (controller.isEditModalOpen &&
                      controller.selectedLayerId != null)
                    Positioned.fill(
                      child: TextEditModal(
                        layerId: controller.selectedLayerId!,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static const double _toolbarHeight = 72.0;
}

// ---------------------------------------------------------------------------
// Back button
// ---------------------------------------------------------------------------

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
