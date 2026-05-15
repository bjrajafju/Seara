import 'dart:typed_data';

/// Audio track attached to a video story.
///
/// Only one audio track is allowed per story.
/// - Always starts at time 0.
/// - If longer than the video → will be trimmed at export.
/// - If shorter → the video continues without audio after it ends.
///
/// ## Platform Compatibility
/// - **Native**: uses [filePath] to read from disk.
/// - **Web**: uses [webUrl] (Blob URL) and [bytes] because local file paths
///   are not available in the browser sandbox.
class StoryAudio {
  /// Local file path (native only). Null on Web.
  final String? filePath;

  /// Blob URL generated for browser playback (web only).
  /// Must be revoked on removal/replacement to avoid memory leaks.
  final String? webUrl;

  /// Raw file bytes (primarily for Web export/persistence).
  final Uint8List? bytes;

  /// Filename for UI display.
  final String fileName;

  /// Duration of the audio in seconds.
  /// Used at export time for trim logic.
  final double durationSeconds;

  const StoryAudio({
    this.filePath,
    this.webUrl,
    this.bytes,
    required this.fileName,
    required this.durationSeconds,
  });

  /// Whether this audio source is valid for the current platform.
  bool get isValid =>
      (filePath != null && filePath!.isNotEmpty) ||
      (webUrl != null && webUrl!.isNotEmpty) ||
      (bytes != null && bytes!.isNotEmpty);
}
