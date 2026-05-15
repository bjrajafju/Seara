// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation: Creates a real Blob URL.
String? createBlobUrl(Uint8List bytes) {
  final blob = html.Blob([bytes]);
  return html.Url.createObjectUrlFromBlob(blob);
}

/// Web implementation: Revokes the Blob URL.
void revokeBlobUrl(String? url) {
  if (url != null && url.startsWith('blob:')) {
    html.Url.revokeObjectUrl(url);
  }
}
