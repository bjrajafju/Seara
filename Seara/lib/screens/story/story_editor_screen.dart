import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import '../../models/story/story_draft.dart';
import '../../widgets/editor/editor_canvas.dart';
import '../../widgets/editor/editor_toolbar.dart';
import '../../widgets/editor/text_edit_modal.dart';
import '../../widgets/story/story_viewport.dart';

/// Root screen for the story editor.
///
/// ## Layout
/// - [StoryViewport] constrains the canvas to the global 9:16 mobile frame,
///   centred on larger screens against a black background.
/// - [EditorToolbar] is positioned on the RIGHT side, OUTSIDE the viewport
///   so the composition frame stays clean and stable.
/// - [TextEditModal] overlays the full screen when editing text (its content
///   is internally constrained to [StoryViewport.maxWidth]).
///
/// [Scaffold.resizeToAvoidBottomInset] is false so the canvas never resizes
/// when the soft keyboard opens inside [TextEditModal].
class StoryEditorScreen extends StatefulWidget {
  final StoryDraft draft;

  const StoryEditorScreen({super.key, required this.draft});

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
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
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Consumer<EditorController>(
            builder: (context, controller, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── 9:16 composition canvas ───────────────────────────────
                  // StoryViewport centres and constrains — identical frame to
                  // the camera preview and export boundary.
                  StoryViewport(child: EditorCanvas(repaintKey: _canvasKey)),

                  // ── Right-side vertical toolbar (OUTSIDE the viewport) ─────
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(child: EditorToolbar(canvasKey: _canvasKey)),
                  ),

                  // ── Back button ───────────────────────────────────────────
                  Positioned(top: 8, left: 8, child: _BackButton()),

                  // ── Text edit modal (OUTSIDE viewport, content constrained) ─
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
