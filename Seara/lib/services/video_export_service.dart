import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show GlobalKey;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../models/story/story_draft.dart';
import '../models/story/story_media.dart';
import 'video_export/export_result.dart';
import 'video_export/ffmpeg_command_builder.dart';
import 'video_export/ffmpeg_executor.dart';
import 'video_export/io_file_helper.dart';
// Web-specific implementation (compiled only for web targets via conditional).
import 'video_export/video_export_web_stub.dart'
    if (dart.library.html) 'video_export/video_export_web.dart'
    as web_export;
import '../utils/export/export_saver.dart' as saver;

/// Orchestrates the full video export pipeline.
///
/// ## Platform routing
/// - **Web**: [HTMLCanvasElement] + [MediaRecorder] → WebM download.
/// - **Windows**: bundled `ffmpeg.exe` via `dart:io Process.run` → MP4.
/// - **Android/iOS/macOS**: `ffmpeg_kit_flutter_new` → MP4.
///
/// ## Export flow (native)
/// 1. Capture the overlay-only [RepaintBoundary] → transparent PNG bytes.
/// 2. Write PNG to temp directory.
/// 3. Build the FFmpeg command via [FFmpegCommandBuilder].
/// 4. Execute via [executeFFmpegCommand] (platform-routed).
/// 5. Return an [ExportResult].
///
/// The base video texture is NOT captured via Flutter — it is passed directly
/// to FFmpeg as a file path, bypassing the hardware-texture limitation of
/// [RenderRepaintBoundary.toImage].
class VideoExportService {
  const VideoExportService();

  /// Runs the export for a video [draft].
  ///
  /// [overlayKey] is used to find the [RepaintBoundary] containing text/drawings.
  /// Resolving the boundary internally after a short delay ensures it is
  /// up-to-date and painted after any UI rebuilds.
  ///
  /// [pixelRatio] is no longer passed from outside; it is calculated
  /// internally to force a canonical 1080x1920 export resolution.
  Future<ExportResult> exportVideo({
    required StoryDraft draft,
    required GlobalKey overlayKey,
  }) async {
    // ── Step 0: Ensure the boundary is painted ──────────────────────────────
    // Wait for at least one frame (plus buffer) to ensure the 'busy' state
    // rebuild has finished and the overlay boundary has been painted.
    await Future.delayed(const Duration(milliseconds: 100));

    final boundary =
        overlayKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return ExportFailure('Could not find overlay capture boundary.');
    }

    // ── Step 1: Calculate canonical pixel ratio ─────────────────────────────
    // We want exactly 1080x1920. The viewport is already constrained to 9:16
    // logically. We derive the scale factor to reach 1080 horizontal pixels.
    final logicalWidth = boundary.size.width;
    final targetPixelRatio = 1080.0 / logicalWidth;

    // Always render the overlay PNG first — needed on all platforms.
    final overlayBytes = await _captureOverlay(boundary, targetPixelRatio);
    if (overlayBytes == null) {
      return ExportFailure('Failed to render overlay image.');
    }

    // ── Web path ─────────────────────────────────────────────────────────────
    if (kIsWeb) {
      final media = _videoMedia(draft);
      if (media == null) {
        return ExportFailure('No video source found in draft.');
      }

      // Web-native MediaRecorder handles composition in real-time.
      // Note: External audio mixing is not currently supported on Web
      // (degraded behavior), but the export is no longer blocked.

      return web_export.exportVideoOnWeb(
        draft: draft,
        videoSrc: media.filePath,
        overlayPngBytes: overlayBytes,
      );
    }

    // ── Native path (Windows / Android / iOS / macOS) ─────────────────────
    final media = _videoMedia(draft);
    if (media == null) {
      return ExportFailure('No video source found in draft.');
    }
    if (media.filePath.isEmpty || _isRemoteUrl(media.filePath)) {
      return ExportFailure(
        'Video export requires a local file path. '
        'Blob/network URLs are not supported yet.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final overlayPath = '${tempDir.path}/overlay_$timestamp.png';
    final outputPath = '${tempDir.path}/story_$timestamp.mp4';

    await writeBytes(overlayPath, overlayBytes);

    final command = FFmpegCommandBuilder.build(
      draft: draft,
      videoPath: media.filePath,
      overlayPath: overlayPath,
      outputPath: outputPath,
    );

    final success = await executeFFmpegCommand(command);

    try {
      await deleteFile(overlayPath);
    } catch (_) {}

    if (!success) {
      return ExportFailure(
        'FFmpeg composition failed. Check device storage and try again.',
      );
    }

    // Move to final destination (Downloads or Gallery)
    final finalLocation = await saver.saveExportedVideo(outputPath);

    return ExportSuccess(finalLocation);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<Uint8List?> _captureOverlay(
    RenderRepaintBoundary? boundary,
    double pixelRatio,
  ) async {
    if (boundary == null) return null;
    try {
      await Future.delayed(Duration.zero);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      // ignore: avoid_print
      print('[VideoExportService] overlay capture failed: $e');
      return null;
    }
  }

  StoryMedia? _videoMedia(StoryDraft draft) {
    try {
      return draft.media.firstWhere((m) => m.isVideo);
    } catch (_) {
      return null;
    }
  }

  static bool _isRemoteUrl(String path) =>
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('blob:');
}
