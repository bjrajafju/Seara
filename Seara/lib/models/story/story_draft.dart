import 'drawing_overlay.dart';
import 'story_audio.dart';
import 'story_media.dart';
import 'story_type.dart';
import 'text_overlay.dart';

/// The root model for a story being created or edited.
///
/// Holds all data needed to represent a story in progress:
/// media, overlays, audio, and mute state.
class StoryDraft {
  /// What kind of story this is (photo, video, layout).
  final StoryType type;

  /// Media files attached to this story.
  /// - Photo / Video → single item.
  /// - Layout → multiple images.
  final List<StoryMedia> media;

  /// All text overlays placed on the story.
  /// Multiple texts are allowed; order is by [TextOverlay.zIndex].
  final List<TextOverlay> textOverlays;

  /// The single drawing layer. Always rendered behind text overlays.
  /// Lazily created — null means the user hasn't drawn anything yet.
  DrawingOverlay? drawingOverlay;

  /// Optional audio track (only meaningful for video stories).
  /// At most one audio track is allowed.
  StoryAudio? audio;

  /// Whether the original video audio is muted.
  /// Only relevant when [type] is [StoryType.video].
  bool isMuted;

  /// Layout preset identifier (e.g. "grid4", "2h", "2v").
  /// Only relevant when [type] is [StoryType.layout]. No logic applied here.
  final String? layoutType;

  /// Index of the layout slot currently being edited.
  /// Only relevant when [type] is [StoryType.layout]. No logic applied here.
  int? activeLayoutIndex;

  StoryDraft({
    required this.type,
    required this.media,
    List<TextOverlay>? textOverlays,
    this.drawingOverlay,
    this.audio,
    this.isMuted = false,
    this.layoutType,
    this.activeLayoutIndex,
  }) : textOverlays = textOverlays ?? [];

  // ---------------------------------------------------------------------------
  // Text overlay helpers
  // ---------------------------------------------------------------------------

  /// The highest zIndex currently in use across all text overlays,
  /// or 0 if there are none.
  int get _maxTextZIndex =>
      textOverlays.isEmpty
          ? 0
          : textOverlays
              .map((t) => t.zIndex)
              .reduce((a, b) => a > b ? a : b);

  /// Add a new text overlay. It is automatically placed on top.
  void addTextOverlay(TextOverlay overlay) {
    overlay.zIndex = _maxTextZIndex + 1;
    textOverlays.add(overlay);
  }

  /// Remove a text overlay by identity.
  void removeTextOverlay(TextOverlay overlay) {
    textOverlays.remove(overlay);
  }

  /// Bring the given text overlay to the front (e.g. on drag).
  void bringTextToFront(TextOverlay overlay) {
    overlay.bringToFront(_maxTextZIndex);
  }

  // ---------------------------------------------------------------------------
  // Drawing helpers
  // ---------------------------------------------------------------------------

  /// Ensures a [DrawingOverlay] exists and returns it.
  ///
  /// [id] is only used when creating the overlay for the first time.
  /// If the overlay already exists, [id] is ignored.
  DrawingOverlay ensureDrawingOverlay({required String id}) {
    drawingOverlay ??= DrawingOverlay(id: id);
    return drawingOverlay!;
  }

  /// Clears all drawing strokes. Does NOT remove the overlay itself.
  void clearDrawing() {
    drawingOverlay?.clearAll();
  }

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  /// Whether there are any overlays (text or drawing) on this story.
  bool get hasOverlays =>
      textOverlays.isNotEmpty ||
      (drawingOverlay != null && !drawingOverlay!.isEmpty);

  /// Whether this draft has an audio track attached.
  bool get hasAudio => audio != null;
}
