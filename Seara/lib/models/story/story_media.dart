import 'dart:typed_data';

/// Represents a media file attached to a story.
///
/// [filePath] holds a local path (mobile/Windows), a blob URL (web video),
/// or an empty string when [bytes] carries the data (web photo).
class StoryMedia {
  /// Local file path, blob URL, or empty string when bytes are used.
  final String filePath;

  /// MIME type (e.g. "image/jpeg", "video/mp4").
  final String mimeType;

  /// Duration of the media in seconds.
  /// Only relevant for video — null for images.
  final double? durationSeconds;

  /// Raw bytes for web photo captures.
  /// Null on mobile / Windows where [filePath] is used instead.
  final Uint8List? bytes;

  /// Whether this media should be flipped horizontally (e.g. front camera capture).
  final bool isMirrored;

  const StoryMedia({
    required this.filePath,
    required this.mimeType,
    this.durationSeconds,
    this.bytes,
    this.isMirrored = false,
  });

  /// Quick helper to check the media category.
  bool get isVideo => mimeType.startsWith('video/');
  bool get isImage => mimeType.startsWith('image/');

  /// True when this asset is stored as bytes rather than a file path.
  bool get isInMemory => bytes != null;
}
