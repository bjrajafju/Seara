// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser file download for [bytes] as a PNG.
///
/// Returns a fixed label string — there is no meaningful file path on web.
/// Used exclusively on web — never imported by mobile/Windows builds.
Future<String> saveExportedImage(Uint8List bytes) async {
  final fileName = 'story_${DateTime.now().millisecondsSinceEpoch}.png';
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = fileName;

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return fileName;
}
