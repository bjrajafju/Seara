import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import '../../controllers/story_feed_controller.dart';
import '../../models/story/story_draft.dart';
import '../../services/feed/story_publish_service.dart';
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
/// - "Postar" button top-right — publishes the story to the backend.
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
  final _publishService = StoryPublishService();

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

  // ── Publish flow ─────────────────────────────────────────────────────────────

  Future<void> _onPublish() async {
    if (_controller.isBusy) return;
    if (widget.draft.media.isEmpty) return;

    _controller.beginPublishing();

    try {
      await _publishService.publish(widget.draft);

      if (!mounted) return;

      // Refresh the feed so the new story appears immediately.
      final feedController = _tryGetFeedController();
      if (feedController != null) {
        unawaited(feedController.fetch());
      }

      _showToast('Story publicado! 🎉');

      // Return to home.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on StoryPublishException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Erro ao publicar. Tenta novamente.');
    } finally {
      if (mounted) _controller.endPublishing();
    }
  }

  /// Safely tries to read StoryFeedController from the tree.
  /// Returns null if it is not available (e.g. deep navigation stack).
  StoryFeedController? _tryGetFeedController() {
    try {
      return context.read<StoryFeedController>();
    } catch (_) {
      return null;
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
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

                  // ── Postar button (top-right) ─────────────────────────────
                  Positioned(
                    top: 8,
                    right: 70, // left of the toolbar column
                    child: _PostarButton(
                      isPublishing: controller.isPublishing,
                      isBusy: controller.isBusy,
                      onTap: _onPublish,
                    ),
                  ),

                  // ── Audio toolbar (video stories, above the bottom edge) ───
                  if (controller.isVideoStory)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: const AudioToolbar(),
                    ),

                  // ── Drawing toolbar (shown during draw mode) ──────────────
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

// ── Postar Button ─────────────────────────────────────────────────────────────

class _PostarButton extends StatelessWidget {
  final bool isPublishing;
  final bool isBusy;
  final VoidCallback onTap;

  const _PostarButton({
    required this.isPublishing,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isBusy ? Colors.white24 : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: isPublishing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black54,
                ),
              )
            : const Text(
                'Postar',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

// ── Back Button ───────────────────────────────────────────────────────────────

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

// ── Helper ────────────────────────────────────────────────────────────────────

void unawaited(Future<void> future) {
  // Fire-and-forget: errors are silently ignored.
  future.catchError((_) {});
}
