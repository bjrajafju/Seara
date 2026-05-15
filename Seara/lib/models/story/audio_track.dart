/// Metadata for an external audio track attached to a video story.
///
/// Only one audio track is supported per story.
/// - Always starts at time 0 (no offset).
/// - If longer than the video → trimmed to video duration at export.
/// - If shorter → video continues silently (or original audio continues if mixed).
class AudioTrack {
  /// Absolute local file path to the audio file (MP3, AAC, WAV, etc.).
  final String filePath;

  /// Duration of the audio track. Used for trim logic at export time.
  final Duration duration;

  /// Human-readable filename shown in the UI (e.g. "my_track.mp3").
  final String displayName;

  const AudioTrack({
    required this.filePath,
    required this.duration,
    required this.displayName,
  });

  /// Duration formatted as mm:ss for display purposes.
  String get formattedDuration {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
