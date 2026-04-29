/// Represents a media file attached to a story.
///
/// This is a simple wrapper around a file path so the model
/// layer stays decoupled from Flutter's File / XFile types.
class StoryMedia {
  /// Local file path to the media asset.
  final String filePath;

  /// MIME type (e.g. "image/jpeg", "video/mp4").
  /// Useful for downstream encoding decisions.
  final String mimeType;

  /// Duration of the media in seconds.
  /// Only relevant for video — null for images.
  final double? durationSeconds;

  const StoryMedia({
    required this.filePath,
    required this.mimeType,
    this.durationSeconds,
  });

  /// Quick helper to check the media category.
  bool get isVideo => mimeType.startsWith('video/');
  bool get isImage => mimeType.startsWith('image/');
}
