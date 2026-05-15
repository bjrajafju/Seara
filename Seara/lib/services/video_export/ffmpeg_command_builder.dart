import '../../models/story/story_draft.dart';

/// Builds the FFmpeg command string for video composition.
///
/// Handles 4 audio cases based on [StoryDraft] state:
///
/// | Case | isMuted | audio  | retainOriginal | Description                     |
/// |------|---------|--------|----------------|---------------------------------|
/// | A    | false   | null   | —              | Original audio only              |
/// | B    | true    | null   | —              | Silent video                     |
/// | C    | true    | set    | —              | External audio only              |
/// | D    | false   | set    | true           | External + original mixed       |
///
/// When `isMuted=false` and `audio!=null` and `retainOriginalAudio=false`,
/// external audio replaces the original (treated as Case C semantics).
class FFmpegCommandBuilder {
  /// Builds the full FFmpeg command for compositing [draft].
  ///
  /// [videoPath]   — absolute path to the base video file.
  /// [overlayPath] — absolute path to the transparent overlay PNG.
  /// [outputPath]  — absolute path where the MP4 should be written.
  ///
  /// The overlay PNG is expected to be exactly the same pixel dimensions
  /// as the video (scaled correctly by [VideoExportService] before calling here).
  static String build({
    required StoryDraft draft,
    required String videoPath,
    required String overlayPath,
    required String outputPath,
  }) {
    final hasExternalAudio = draft.audio != null;
    final isMuted = draft.isMuted;
    final audioPath = draft.audio?.filePath;

    // ── Determine which audio case applies (Phase 4 rules) ──────────────────
    // 1. No external + unmuted -> Original audio only (Case A)
    // 2. No external + muted   -> Silent video (Case B)
    // 3. External + muted      -> External audio only (Case C)
    // 4. External + unmuted    -> Mixed original + external (Case D)

    final isMirrored = draft.media.isNotEmpty && draft.media.first.isMirrored;

    if (!hasExternalAudio) {
      return isMuted
          ? _caseB(videoPath, overlayPath, outputPath, isMirrored)
          : _caseA(videoPath, overlayPath, outputPath, isMirrored);
    } else {
      return isMuted
          ? _caseC(videoPath, overlayPath, audioPath!, outputPath, isMirrored)
          : _caseD(videoPath, overlayPath, audioPath!, outputPath, isMirrored);
    }
  }

  // ── Case implementations ────────────────────────────────────────────────

  /// Case A: overlay PNG over video, keep original audio track.
  static String _caseA(
    String video,
    String overlay,
    String output,
    bool isMirrored,
  ) {
    final vFilter = isMirrored ? 'hflip,' : '';
    return '-y '
        '-i "$video" '
        '-loop 1 -i "$overlay" '
        '-filter_complex "[0:v]${vFilter}scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920[bg];[bg][1:v]overlay=0:0:shortest=1[v]" '
        '-map "[v]" -map 0:a? '
        '-c:v libx264 -preset fast -crf 23 '
        '-c:a aac -b:a 128k '
        '"$output"';
  }

  /// Case B: overlay PNG over video, strip all audio.
  static String _caseB(
    String video,
    String overlay,
    String output,
    bool isMirrored,
  ) {
    final vFilter = isMirrored ? 'hflip,' : '';
    return '-y '
        '-i "$video" '
        '-loop 1 -i "$overlay" '
        '-filter_complex "[0:v]${vFilter}scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920[bg];[bg][1:v]overlay=0:0:shortest=1[v]" '
        '-map "[v]" '
        '-c:v libx264 -preset fast -crf 23 '
        '-an '
        '"$output"';
  }

  /// Case C: overlay PNG over video, use external audio only (trim/pad to video duration).
  static String _caseC(
    String video,
    String overlay,
    String audio,
    String output,
    bool isMirrored,
  ) {
    final vFilter = isMirrored ? 'hflip,' : '';
    return '-y '
        '-i "$video" '
        '-loop 1 -i "$overlay" '
        '-i "$audio" '
        '-filter_complex '
        '"[0:v]${vFilter}scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920[bg];'
        '[bg][1:v]overlay=0:0:shortest=1[v];'
        '[2:a]apad[a]" '
        '-map "[v]" -map "[a]" '
        '-c:v libx264 -preset fast -crf 23 '
        '-c:a aac -b:a 128k '
        '-shortest '
        '"$output"';
  }

  /// Case D: overlay PNG over video, mix external audio with original track (video is master).
  static String _caseD(
    String video,
    String overlay,
    String audio,
    String output,
    bool isMirrored,
  ) {
    final vFilter = isMirrored ? 'hflip,' : '';
    return '-y '
        '-i "$video" '
        '-loop 1 -i "$overlay" '
        '-i "$audio" '
        '-filter_complex '
        '"[0:v]${vFilter}scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920[bg];'
        '[bg][1:v]overlay=0:0:shortest=1[v];'
        '[0:a][2:a]amix=inputs=2:duration=first[a]" '
        '-map "[v]" -map "[a]" '
        '-c:v libx264 -preset fast -crf 23 '
        '-c:a aac -b:a 128k '
        '-shortest '
        '"$output"';
  }
}
