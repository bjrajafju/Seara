// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Generates a human-friendly filename like seara_2026-05-14_14-32-10.ext
String _generateFileName(String extension) {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  final second = now.second.toString().padLeft(2, '0');

  return 'seara_${year}-$month-$day\_$hour-$minute-$second.$extension';
}

/// Triggers a browser file download for [bytes] as a PNG.
///
/// Returns a fixed label string — there is no meaningful file path on web.
/// Used exclusively on web — never imported by mobile/Windows builds.
Future<String> saveExportedImage(Uint8List bytes) async {
  final fileName = _generateFileName('png');
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

/// No-op on web for video files, as they are usually handled
/// during the export process itself.
Future<String> saveExportedVideo(String pathOrName) async {
  return pathOrName;
}
