import 'dart:io';
import 'dart:typed_data';

/// Writes [bytes] to [path] using dart:io (native platforms only).
Future<void> writeBytes(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
}

/// Deletes the file at [path] (best-effort, native platforms only).
Future<void> deleteFile(String path) async {
  await File(path).delete();
}
