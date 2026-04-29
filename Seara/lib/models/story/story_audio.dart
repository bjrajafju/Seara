/// Audio track attached to a video story.
///
/// Only one audio track is allowed per story.
/// - Always starts at time 0.
/// - If longer than the video → will be trimmed at export.
/// - If shorter → the video continues without audio.
class StoryAudio {
  /// Local file path to the audio file.
  final String filePath;

  /// Duration of the audio in seconds.
  /// Used at export time for trim logic.
  final double durationSeconds;

  const StoryAudio({
    required this.filePath,
    required this.durationSeconds,
  });
}
