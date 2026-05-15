import 'dart:typed_data';

import '../../models/story/story_draft.dart';
import 'export_result.dart';

/// Native stub for the web canvas recorder.
///
/// This function is never called on native platforms because
/// [VideoExportService] routes to the FFmpeg pipeline first.
/// It exists only so the conditional import compiles on all targets.
Future<ExportResult> exportVideoOnWeb({
  required StoryDraft draft,
  required String videoSrc,
  required Uint8List overlayPngBytes,
}) async {
  return ExportUnsupported(
    'Web canvas export called on a non-web platform — this should not happen.',
  );
}

Future<String> saveExportedVideo(String pathOrName) async {
  throw UnimplementedError('saveExportedVideo called on stub.');
}
