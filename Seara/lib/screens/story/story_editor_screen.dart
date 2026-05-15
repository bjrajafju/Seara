import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import '../../models/story/story_draft.dart';
import '../../widgets/editor/audio_toolbar.dart';
import '../../widgets/editor/drawing_toolbar.dart';
import '../../widgets/editor/editor_canvas.dart';
import '../../widgets/editor/editor_toolbar.dart';
import '../../widgets/editor/text_edit_modal.dart';
import '../../widgets/story/story_viewport.dart';

/// Root screen for the story editor.
///
/// ## Layout
/// - [StoryViewport] constrains the canvas to the 9:16 mobile frame.
/// - [EditorToolbar] is positioned RIGHT of the viewport (outside composition).
/// - [DrawingToolbar] slides up from the bottom when drawing mode is active.
/// - [AudioToolbar] is anchored below the viewport for video stories.
/// - [TextEditModal] overlays the full screen when editing text.
///
/// Two [GlobalKey]s are managed here:
/// - [_canvasKey]  → full-composition [RepaintBoundary] (image export).
/// - [_overlayKey] → overlay-only [RepaintBoundary] (video FFmpeg export).
class StoryEditorScreen extends StatefulWidget {
  final StoryDraft draft;

  const StoryEditorScreen({super.key, required this.draft});

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey _overlayKey = GlobalKey();
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
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Consumer<EditorController>(
            builder: (context, controller, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── 9:16 composition canvas ───────────────────────────────
                  StoryViewport(
                    child: EditorCanvas(
                      repaintKey: _canvasKey,
                      overlayRepaintKey: _overlayKey,
                    ),
                  ),

                  // ── Right-side vertical toolbar (OUTSIDE the viewport) ─────
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: EditorToolbar(
                        canvasKey: _canvasKey,
                        overlayKey: _overlayKey,
                      ),
                    ),
                  ),

                  // ── Back button ───────────────────────────────────────────
                  Positioned(top: 8, left: 8, child: _BackButton()),

                  // ── Audio toolbar (video stories, above the bottom edge) ───
                  if (controller.isVideoStory)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: const AudioToolbar(),
                    ),

                  // ── Drawing toolbar (shown during draw mode) ──────────────
                  // Positioned above AudioToolbar when both are visible.
                  if (controller.isDrawingMode)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: controller.isVideoStory ? 64 : 0,
                      child: const DrawingToolbar(),
                    ),

                  // ── Text edit modal ───────────────────────────────────────
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
}

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
