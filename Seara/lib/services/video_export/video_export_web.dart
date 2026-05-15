// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import '../../models/story/story_draft.dart';
import 'export_result.dart';
import 'ffmpeg_command_builder.dart';
import 'ffmpeg_executor_web.dart';

/// Web video export using FFmpeg WASM.
///
/// ## Strategy
/// Following the required architecture:
/// 1. Fetch video and audio sources as raw bytes (Blobs or remote URLs).
/// 2. Prepare virtual file system via [setFFmpegInputFiles].
/// 3. Build the same FFmpeg command as native via [FFmpegCommandBuilder].
/// 4. Execute via [executeFFmpegCommand] (WASM).
/// 5. Extract result and trigger browser download.
Future<ExportResult> exportVideoOnWeb({
  required StoryDraft draft,
  required String videoSrc,
  required Uint8List overlayPngBytes,
}) async {
  // ── Step 0: Runtime Guard ───────────────────────────────────────────────
  // FFmpeg WASM requires SharedArrayBuffer, which is only available if the
  // site is served with cross-origin isolation headers.
  final hasSharedArrayBuffer = js_util.hasProperty(
    html.window,
    'SharedArrayBuffer',
  );

  if (!hasSharedArrayBuffer) {
    return ExportFailure(
      'Browser video export requires cross-origin isolation headers '
      '(COOP/COEP). Please check deployment configuration.',
    );
  }

  try {
    const videoPath = 'input.mp4';
    const overlayPath = 'overlay.png';
    const audioPath = 'audio.mp3';
    const outputPath = 'output.mp4';

    // ── 1. Fetch source bytes ────────────────────────────────────────────────
    final videoBytes = await _fetchBytes(videoSrc);

    Uint8List? audioBytes;
    final externalAudioSrc = draft.audio?.webUrl ?? draft.audio?.filePath;
    if (externalAudioSrc != null) {
      audioBytes = await _fetchBytes(externalAudioSrc);
    }

    // ── 2. Prepare Virtual FS ───────────────────────────────────────────────
    final Map<String, Uint8List> inputFiles = {
      videoPath: videoBytes,
      overlayPath: overlayPngBytes,
    };
    if (audioBytes != null) {
      inputFiles[audioPath] = audioBytes;
    }

    setFFmpegInputFiles(inputFiles);

    // ── 3. Build Command ────────────────────────────────────────────────────
    // We use the exact same builder as Native.
    final command = FFmpegCommandBuilder.build(
      draft: draft,
      videoPath: videoPath,
      overlayPath: overlayPath,
      outputPath: outputPath,
    );

    // ── 4. Execute FFmpeg WASM ──────────────────────────────────────────────
    final success = await executeFFmpegCommand(command);

    if (!success) {
      return ExportFailure('FFmpeg WASM composition failed.');
    }

    // ── 5. Handle Output ────────────────────────────────────────────────────
    final outputBytes = getFFmpegOutput();
    if (outputBytes == null) {
      return ExportFailure('FFmpeg output was not found in virtual FS.');
    }

    final fileName = 'seara_${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}_${DateTime.now().hour.toString().padLeft(2, '0')}-${DateTime.now().minute.toString().padLeft(2, '0')}-${DateTime.now().second.toString().padLeft(2, '0')}.mp4';
    _triggerDownload(outputBytes, fileName);

    return ExportSuccess(fileName);
  } catch (e) {
    return ExportFailure('Web FFmpeg export failed: $e');
  }
}

Future<Uint8List> _fetchBytes(String url) async {
  final response = await html.window.fetch(url);
  final blob = await response.blob();
  final reader = html.FileReader();
  final completer = Completer<Uint8List>();

  reader.onLoadEnd.listen((_) {
    completer.complete(reader.result as Uint8List);
  });
  reader.readAsArrayBuffer(blob);

  return completer.future.timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw 'Fetch timed out for: $url',
  );
}

void _triggerDownload(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes], 'video/mp4');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
