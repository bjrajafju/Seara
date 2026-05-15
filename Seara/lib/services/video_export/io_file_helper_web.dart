import 'dart:typed_data';

/// Web stub — these functions are never called on web because VideoExportService
/// returns [ExportUnsupported] before reaching file I/O.
Future<void> writeBytes(String path, Uint8List bytes) async {}
Future<void> deleteFile(String path) async {}
