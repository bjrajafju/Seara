import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';
import '../../models/story/story_audio.dart';
import '../../utils/media/blob_url_helper.dart'
    if (dart.library.html) '../../utils/media/blob_url_helper_web.dart'
    as blob_helper;

/// Audio controls panel for video stories.
///
/// Shown as a bottom overlay in [StoryEditorScreen] when the draft is a video.
/// Provides:
/// - External audio track upload (via [file_picker]).
/// - Duration label for the attached track (calculated via [just_audio]).
/// - Remove audio button.
///
/// The panel is only visible for video drafts.
class AudioToolbar extends StatelessWidget {
  const AudioToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EditorController>();
    final track = ctrl.audioTrack;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xDD1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // ── Track info or upload prompt ──────────────────────────────────
          Expanded(
            child: track == null
                ? _UploadPrompt(onTap: () => _pickAudio(context))
                : _TrackInfo(track: track),
          ),

          const SizedBox(width: 12),

          if (track != null) ...[
            // ── Remove audio ───────────────────────────────────────────────
            GestureDetector(
              onTap: () => context.read<EditorController>().removeAudioTrack(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withAlpha(200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ] else ...[
            // ── Upload button (icon-only) when no track ──────────────────
            GestureDetector(
              onTap: () => _pickAudio(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAudio(BuildContext context) async {
    // 1. Picker with strict filtering and cross-platform data loading.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: kIsWeb, // Required on Web to get bytes.
    );

    if (!context.mounted) return;
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    // Web safety: NEVER access .path getter on Web.
    String? path;
    if (!kIsWeb) {
      path = file.path;
    }

    final bytes = file.bytes;

    if (kIsWeb && bytes == null) return;
    if (!kIsWeb && path == null) return;

    // 2. Platform-specific source preparation.
    String? webUrl;
    if (kIsWeb) {
      // Create a blob URL for native browser playback.
      webUrl = blob_helper.createBlobUrl(bytes!);
    }

    // 3. Use just_audio to get the actual duration of the file.
    final player = AudioPlayer();
    double durationSecs = 0.0;
    try {
      // Platform-safe audio source selection.
      final source = kIsWeb
          ? AudioSource.uri(Uri.parse(webUrl!))
          : AudioSource.uri(Uri.file(path!));

      final dur = await player.setAudioSource(source);
      if (dur != null) {
        durationSecs = dur.inMilliseconds / 1000.0;
      }
    } catch (e) {
      debugPrint('[AudioToolbar] Could not get audio duration: $e');
    } finally {
      await player.dispose();
    }

    if (!context.mounted) return;

    // 4. Commit to controller using the platform-safe model.
    context.read<EditorController>().setAudioTrack(
      StoryAudio(
        fileName: file.name,
        filePath: path,
        webUrl: webUrl,
        bytes: bytes,
        durationSeconds: durationSecs,
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _UploadPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Row(
        children: [
          Icon(Icons.music_note_rounded, color: Colors.white38, size: 20),
          SizedBox(width: 10),
          Text(
            'Add music track...',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final StoryAudio track;
  const _TrackInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    final secs = track.durationSeconds.toInt();
    final durStr = secs > 0
        ? '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}'
        : '--:--';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.audiotrack_rounded,
              color: Colors.blueAccent,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                track.fileName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          durStr,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
